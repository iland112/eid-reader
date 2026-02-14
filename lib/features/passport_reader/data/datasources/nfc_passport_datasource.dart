import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:logging/logging.dart';

import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';

final _log = Logger('NfcPassportDatasource');

/// Reads e-Passport data via NFC using the dmrtd library.
class NfcPassportDatasource {
  final NfcProvider _nfc = NfcProvider();

  /// Reads passport data using NFC.
  ///
  /// Attempts PACE first, falls back to BAC if not supported.
  /// Reads DG1 (MRZ biographical data) and DG2 (face image).
  Future<PassportData> readPassport(MrzData mrzData) async {
    String authProtocol = 'BAC';

    try {
      _log.info('Connecting to NFC...');
      await _nfc.connect(
        iosAlertMessage: 'Hold your phone near the passport',
      );

      final passport = Passport(_nfc);

      // Try PACE first, fall back to BAC
      final dbaKey = DbaKey(
        mrzData.documentNumber,
        mrzData.dateOfBirth,
        mrzData.dateOfExpiry,
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
      final efCom = await passport.readEfCOM();

      // Read DG1 (MRZ data)
      _log.info('Reading DG1...');
      final dg1 = await passport.readEfDG1();

      // Read DG2 (face image) if available
      _log.info('Reading DG2...');
      Uint8List? faceImageBytes;
      try {
        final dg2 = await passport.readEfDG2();
        faceImageBytes = dg2.faceData;
      } catch (e) {
        _log.warning('Could not read DG2: $e');
      }

      // Disconnect
      await _nfc.disconnect(
        iosAlertMessage: 'Reading complete',
      );

      // Parse MRZ from DG1
      final mrz = dg1.mrz;

      return PassportData(
        surname: mrz.lastName,
        givenNames: mrz.firstName,
        documentNumber: mrz.documentNumber,
        nationality: mrz.nationality,
        dateOfBirth: mrz.dateOfBirth,
        sex: mrz.gender,
        dateOfExpiry: mrz.dateOfExpiry,
        issuingState: mrz.country,
        documentType: mrz.documentType,
        faceImageBytes: faceImageBytes,
        authProtocol: authProtocol,
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
