import 'package:dmrtd/dmrtd.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../../../core/image/image_utils.dart';
import '../../../../core/platform/pcsc_provider.dart';
import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';
import 'passport_datasource.dart';
import 'passport_read_result.dart';

final _log = Logger('PcscPassportDatasource');

String _formatYYMMDD(DateTime date) {
  final y = (date.year % 100).toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

DateTime _parseYYMMDD(String yymmdd) {
  final yy = int.parse(yymmdd.substring(0, 2));
  final mm = int.parse(yymmdd.substring(2, 4));
  final dd = int.parse(yymmdd.substring(4, 6));
  final year = yy < 70 ? 2000 + yy : 1900 + yy;
  return DateTime(year, mm, dd);
}

/// Reads e-Passport data via PC/SC USB smart card reader.
///
/// Uses the same dmrtd Passport API as [NfcPassportDatasource] but with
/// [PcscProvider] instead of [FastNfcProvider].
class PcscPassportDatasource implements PassportDatasource {
  final String? preferredReader;

  PcscPassportDatasource({this.preferredReader});

  @override
  Future<PassportReadResult> readPassport(MrzData mrzData) async {
    String authProtocol = 'BAC';
    final timings = <String, int>{};
    final pcsc = PcscProvider(preferredReader: preferredReader);

    try {
      var sw = Stopwatch()..start();

      _log.info('Connecting to smart card reader...');
      await pcsc.connect(timeout: const Duration(seconds: 30));
      timings['connect'] = sw.elapsedMilliseconds;
      _log.info('Connected in ${sw.elapsedMilliseconds}ms');

      final passport = Passport(pcsc);

      final dbaKey = DBAKey(
        mrzData.documentNumber,
        _parseYYMMDD(mrzData.dateOfBirth),
        _parseYYMMDD(mrzData.dateOfExpiry),
      );

      // Authenticate: BAC
      sw = Stopwatch()..start();
      _log.info('Starting BAC authentication...');
      await passport.startSession(dbaKey);
      authProtocol = 'BAC';
      timings['auth'] = sw.elapsedMilliseconds;
      _log.info('BAC auth in ${sw.elapsedMilliseconds}ms');

      // Read DG1
      sw = Stopwatch()..start();
      _log.info('Reading DG1...');
      final dg1 = await passport.readEfDG1();
      final dg1Bytes = dg1.toBytes();
      timings['dg1'] = sw.elapsedMilliseconds;
      _log.info('DG1 read in ${sw.elapsedMilliseconds}ms (${dg1Bytes.length} bytes)');

      // Read DG2
      sw = Stopwatch()..start();
      _log.info('Reading DG2...');
      Uint8List? faceImageBytes;
      Uint8List dg2Bytes = Uint8List(0);
      try {
        final dg2 = await passport.readEfDG2();
        dg2Bytes = dg2.toBytes();
        faceImageBytes = decodeFaceImage(dg2.imageData!);
        timings['dg2'] = sw.elapsedMilliseconds;
        _log.info('DG2 read in ${sw.elapsedMilliseconds}ms (${dg2Bytes.length} bytes)');
      } catch (e) {
        timings['dg2'] = sw.elapsedMilliseconds;
        _log.warning('DG2 failed after ${sw.elapsedMilliseconds}ms: $e');
      }

      // Read SOD
      sw = Stopwatch()..start();
      _log.info('Reading SOD...');
      Uint8List sodBytes = Uint8List(0);
      try {
        final sod = await passport.readEfSOD();
        sodBytes = sod.toBytes();
        timings['sod'] = sw.elapsedMilliseconds;
        _log.info('SOD read in ${sw.elapsedMilliseconds}ms (${sodBytes.length} bytes)');
      } catch (e) {
        timings['sod'] = sw.elapsedMilliseconds;
        _log.warning('SOD failed after ${sw.elapsedMilliseconds}ms: $e');
      }

      // Disconnect
      await pcsc.disconnect();

      final total = timings.values.fold<int>(0, (a, b) => a + b);
      _log.info('Total PC/SC read: ${total}ms | $timings');

      final mrz = dg1.mrz;

      return PassportReadResult(
        passportData: PassportData(
          surname: mrz.lastName,
          givenNames: mrz.firstName,
          documentNumber: mrz.documentNumber,
          nationality: mrz.nationality,
          dateOfBirth: _formatYYMMDD(mrz.dateOfBirth),
          sex: mrz.gender,
          dateOfExpiry: _formatYYMMDD(mrz.dateOfExpiry),
          issuingState: mrz.country,
          documentType: mrz.documentCode,
          faceImageBytes: faceImageBytes,
          authProtocol: authProtocol,
        ),
        sodBytes: sodBytes,
        dg1Bytes: dg1Bytes,
        dg2Bytes: dg2Bytes,
        stepTimings: timings,
      );
    } catch (e) {
      _log.severe('Passport reading failed: $e | timings so far: $timings');
      try {
        await pcsc.disconnect();
      } catch (_) {}
      rethrow;
    }
  }
}
