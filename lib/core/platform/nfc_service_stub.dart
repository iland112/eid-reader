import 'nfc_service.dart';

/// Stub NFC service for platforms without NFC support (desktop).
class NfcServiceStub implements NfcService {
  @override
  Future<NfcStatus> checkAvailability() async {
    return NfcStatus.notSupported;
  }
}
