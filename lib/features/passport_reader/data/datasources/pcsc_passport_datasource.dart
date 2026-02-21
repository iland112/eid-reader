import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:logging/logging.dart';

import '../../../../core/image/image_utils.dart';
import '../../../../core/platform/pcsc_provider.dart';
import '../../../../core/utils/mrz_utils.dart';
import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';
import 'passport_datasource.dart';
import 'passport_read_result.dart';

final _log = Logger('PcscPassportDatasource');

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
        MrzUtils.parseYYMMDD(mrzData.dateOfBirth),
        MrzUtils.parseYYMMDD(mrzData.dateOfExpiry),
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
        final rawImage = dg2.imageData;
        if (rawImage != null) {
          faceImageBytes = decodeFaceImage(rawImage);
        }
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
          dateOfBirth: MrzUtils.formatYYMMDD(mrz.dateOfBirth),
          sex: mrz.gender,
          dateOfExpiry: MrzUtils.formatYYMMDD(mrz.dateOfExpiry),
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
