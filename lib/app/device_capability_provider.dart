import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/nfc_service.dart';
import '../core/platform/nfc_service_android.dart';
import '../core/platform/pcsc_service.dart';
import '../core/platform/pcsc_service_impl.dart';
import '../features/passport_reader/data/datasources/passport_datasource_factory.dart';

/// Runtime chip reader capability detected on the device.
enum ChipReaderCapability {
  /// NFC hardware is present and enabled (Android/iOS).
  nfcEnabled,

  /// NFC hardware is present but disabled in settings (Android/iOS).
  nfcDisabled,

  /// PC/SC smart card reader is connected (Desktop).
  pcscAvailable,

  /// No chip reader available on this device.
  none,
}

/// Whether the given capability allows chip-based passport reading.
bool hasChipReader(ChipReaderCapability capability) =>
    capability == ChipReaderCapability.nfcEnabled ||
    capability == ChipReaderCapability.pcscAvailable;

/// Detects the device's chip reader capability at runtime.
final chipReaderCapabilityProvider =
    FutureProvider<ChipReaderCapability>((ref) async {
  if (PassportDatasourceFactory.isNfcPlatform) {
    final nfcService = NfcServiceAndroid();
    final status = await nfcService.checkAvailability();
    return switch (status) {
      NfcStatus.enabled => ChipReaderCapability.nfcEnabled,
      NfcStatus.disabled => ChipReaderCapability.nfcDisabled,
      NfcStatus.notSupported => ChipReaderCapability.none,
    };
  }
  if (PassportDatasourceFactory.isPcscPlatform) {
    final pcscService = PcscServiceImpl();
    final status = await pcscService.checkAvailability();
    return status == PcscStatus.available
        ? ChipReaderCapability.pcscAvailable
        : ChipReaderCapability.none;
  }
  return ChipReaderCapability.none;
});
