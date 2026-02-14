/// NFC availability status.
enum NfcStatus {
  /// Device does not have NFC hardware.
  notSupported,

  /// NFC hardware exists but is disabled.
  disabled,

  /// NFC is available and enabled.
  enabled,
}

/// Abstract interface for NFC/smart card communication.
///
/// On Android: implemented via flutter_nfc_kit (through dmrtd NfcProvider).
/// On Desktop (future): will be implemented via PC/SC USB smart card reader.
abstract class NfcService {
  /// Check NFC hardware availability.
  Future<NfcStatus> checkAvailability();
}
