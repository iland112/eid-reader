import 'package:dmrtd/dmrtd.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../../../core/image/image_utils.dart';
import '../../../../core/platform/fast_nfc_provider.dart';
import '../../../../core/utils/mrz_utils.dart';
import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';
import 'passport_datasource.dart';
import 'passport_read_result.dart';

final _log = Logger('NfcPassportDatasource');

/// Reads e-Passport data via NFC using the dmrtd library.
class NfcPassportDatasource implements PassportDatasource {
  final FastNfcProvider _nfc = FastNfcProvider();

  static const int _maxRetries = 3;

  /// Reads passport data using NFC.
  ///
  /// Uses BAC authentication. Retries automatically on NFC communication
  /// errors (TagLost, CommunicationError, Polling timeout) up to
  /// [_maxRetries] times.
  @override
  Future<PassportReadResult> readPassport(MrzData mrzData) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final result = await _readPassportOnce(mrzData);
        return result;
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        final isRetryable = msg.contains('CommunicationError') ||
            msg.contains('TagLost') ||
            msg.contains('tag was lost') ||
            msg.contains('Polling tag timeout');

        _log.warning('Attempt $attempt/$_maxRetries failed: $e');
        try {
          await _nfc.disconnect(iosErrorMessage: 'Reading failed');
        } catch (_) {}

        if (!isRetryable || attempt == _maxRetries) {
          rethrow;
        }

        _log.info('Retrying NFC read (attempt ${attempt + 1}/$_maxRetries)...');
        // Brief pause before retry to let NFC reset
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    // Should not reach here, but just in case
    throw lastError!;
  }

  Future<PassportReadResult> _readPassportOnce(MrzData mrzData) async {
    String authProtocol = 'BAC';
    final timings = <String, int>{};

    try {
      var sw = Stopwatch()..start();

      _log.info('Connecting to NFC...');
      await _nfc.connect(
        timeout: const Duration(seconds: 30),
        iosAlertMessage: 'Hold your phone near the passport',
      );
      timings['connect'] = sw.elapsedMilliseconds;
      _log.info('NFC connected in ${sw.elapsedMilliseconds}ms');

      // Haptic feedback so user knows the tag was detected
      HapticFeedback.heavyImpact();

      final passport = Passport(_nfc);

      final dbaKey = DBAKey(
        mrzData.documentNumber,
        MrzUtils.parseYYMMDD(mrzData.dateOfBirth),
        MrzUtils.parseYYMMDD(mrzData.dateOfExpiry),
      );

      // Authenticate: BAC directly (faster for passports without PACE)
      sw = Stopwatch()..start();
      _log.info('Starting BAC authentication...');
      await passport.startSession(dbaKey);
      authProtocol = 'BAC';
      timings['auth'] = sw.elapsedMilliseconds;
      _log.info('BAC auth in ${sw.elapsedMilliseconds}ms');

      // Read DG1 (MRZ data)
      sw = Stopwatch()..start();
      _log.info('Reading DG1...');
      final dg1 = await passport.readEfDG1();
      final dg1Bytes = dg1.toBytes();
      timings['dg1'] = sw.elapsedMilliseconds;
      _log.info('DG1 read in ${sw.elapsedMilliseconds}ms (${dg1Bytes.length} bytes)');

      // Read DG2 (face image) if available
      sw = Stopwatch()..start();
      _log.info('Reading DG2...');
      Uint8List? faceImageBytes;
      Uint8List dg2Bytes = Uint8List(0);
      try {
        final dg2 = await passport.readEfDG2();
        dg2Bytes = dg2.toBytes();
        // Decode face image (handles JPEG passthrough + JPEG2000 conversion)
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

      // Read SOD (Security Object Document) for Passive Authentication
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
      await _nfc.disconnect(
        iosAlertMessage: 'Reading complete',
      );

      final total = timings.values.fold<int>(0, (a, b) => a + b);
      _log.info('Total NFC read: ${total}ms | $timings');

      // Parse MRZ from DG1
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
        await _nfc.disconnect(iosErrorMessage: 'Reading failed');
      } catch (_) {}
      rethrow;
    }
  }
}
