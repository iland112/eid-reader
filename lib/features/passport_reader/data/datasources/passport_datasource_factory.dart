import 'dart:io';

import 'nfc_passport_datasource.dart';
import 'passport_datasource.dart';
import 'pcsc_passport_datasource.dart';

/// Creates the appropriate [PassportDatasource] for the current platform.
///
/// - Android: [NfcPassportDatasource] (NFC via flutter_nfc_kit)
/// - Desktop (Windows/Linux): [PcscPassportDatasource] (USB smart card reader)
class PassportDatasourceFactory {
  PassportDatasourceFactory._();

  /// Whether the current platform uses NFC for passport reading.
  static bool get isNfcPlatform => Platform.isAndroid || Platform.isIOS;

  /// Whether the current platform uses PC/SC for passport reading.
  static bool get isPcscPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Creates a datasource for the current platform.
  static PassportDatasource create({String? preferredReader}) {
    if (isNfcPlatform) {
      return NfcPassportDatasource();
    }
    if (isPcscPlatform) {
      return PcscPassportDatasource(preferredReader: preferredReader);
    }
    throw UnsupportedError(
        'Passport reading not supported on ${Platform.operatingSystem}');
  }
}
