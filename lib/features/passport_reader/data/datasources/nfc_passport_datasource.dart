import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:logging/logging.dart';

import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';
import 'passport_datasource.dart';
import 'passport_read_result.dart';

final _log = Logger('NfcPassportDatasource');

String _formatYYMMDD(DateTime date) {
  final y = (date.year % 100).toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

/// Parses YYMMDD string to DateTime.
DateTime _parseYYMMDD(String yymmdd) {
  final yy = int.parse(yymmdd.substring(0, 2));
  final mm = int.parse(yymmdd.substring(2, 4));
  final dd = int.parse(yymmdd.substring(4, 6));
  // ICAO 9303: years 00-99 map to 2000-2099 for expiry, 1900-1999 for birth.
  // For DBAKey, the library handles the century internally.
  final year = yy < 70 ? 2000 + yy : 1900 + yy;
  return DateTime(year, mm, dd);
}

/// Reads e-Passport data via NFC using the dmrtd library.
class NfcPassportDatasource implements PassportDatasource {
  final NfcProvider _nfc = NfcProvider();

  /// Reads passport data using NFC.
  ///
  /// Attempts PACE first, falls back to BAC if not supported.
  /// Reads DG1, DG2, and SOD (for Passive Authentication).
  @override
  Future<PassportReadResult> readPassport(MrzData mrzData) async {
    String authProtocol = 'BAC';

    try {
      _log.info('Connecting to NFC...');
      await _nfc.connect(
        timeout: const Duration(seconds: 30),
        iosAlertMessage: 'Hold your phone near the passport',
      );

      final passport = Passport(_nfc);

      // Try PACE first, fall back to BAC
      final dbaKey = DBAKey(
        mrzData.documentNumber,
        _parseYYMMDD(mrzData.dateOfBirth),
        _parseYYMMDD(mrzData.dateOfExpiry),
      );

      try {
        _log.info('Attempting PACE authentication...');
        final cardAccess = await passport.readEfCardAccess();
        // If we can read card access, try PACE
        await passport.startSessionPACE(dbaKey, cardAccess);
        authProtocol = 'PACE';
        _log.info('PACE authentication successful');
      } catch (e) {
        _log.info('PACE not available, falling back to BAC: $e');
        await passport.startSession(dbaKey);
        authProtocol = 'BAC';
        _log.info('BAC authentication successful');
      }

      // Read EF.COM
      _log.info('Reading EF.COM...');
      await passport.readEfCOM();

      // Read DG1 (MRZ data)
      _log.info('Reading DG1...');
      final dg1 = await passport.readEfDG1();
      final dg1Bytes = dg1.toBytes();

      // Read DG2 (face image) if available
      _log.info('Reading DG2...');
      Uint8List? faceImageBytes;
      Uint8List dg2Bytes = Uint8List(0);
      try {
        final dg2 = await passport.readEfDG2();
        faceImageBytes = dg2.imageData;
        dg2Bytes = dg2.toBytes();
      } catch (e) {
        _log.warning('Could not read DG2: $e');
      }

      // Read SOD (Security Object Document) for Passive Authentication
      _log.info('Reading SOD...');
      Uint8List sodBytes = Uint8List(0);
      try {
        final sod = await passport.readEfSOD();
        sodBytes = sod.toBytes();
      } catch (e) {
        _log.warning('Could not read SOD: $e');
      }

      // Disconnect
      await _nfc.disconnect(
        iosAlertMessage: 'Reading complete',
      );

      // Parse MRZ from DG1
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
      );
    } catch (e) {
      _log.severe('Passport reading failed: $e');
      try {
        await _nfc.disconnect(iosErrorMessage: 'Reading failed');
      } catch (_) {}
      rethrow;
    }
  }
}
