import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

import 'nfc_service.dart';

class NfcServiceAndroid implements NfcService {
  @override
  Future<NfcStatus> checkAvailability() async {
    final availability = await FlutterNfcKit.nfcAvailability;
    switch (availability) {
      case NFCAvailability.available:
        return NfcStatus.enabled;
      case NFCAvailability.disabled:
        return NfcStatus.disabled;
      case NFCAvailability.not_supported:
        return NfcStatus.notSupported;
    }
  }
}
