import 'dart:io';
import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:logging/logging.dart';

/// Optimized [ComProvider] for e-Passport NFC reading.
///
/// Compared to dmrtd's default [NfcProvider], this skips:
/// - NDEF discovery (e-Passports don't use NDEF, saves ~500ms)
/// - Platform NFC sound (app provides custom haptic feedback)
class FastNfcProvider extends ComProvider {
  static final _log = Logger('FastNfcProvider');

  Duration timeout = const Duration(seconds: 10);

  NFCTag? _tag;

  FastNfcProvider() : super(_log);

  /// On iOS, sets NFC reader session alert message.
  Future<void> setIosAlertMessage(String message) async {
    if (Platform.isIOS) {
      return await FlutterNfcKit.setIosAlertMessage(message);
    }
  }

  static Future<NfcStatus> get nfcStatus async {
    final a = await FlutterNfcKit.nfcAvailability;
    switch (a) {
      case NFCAvailability.disabled:
        return NfcStatus.disabled;
      case NFCAvailability.available:
        return NfcStatus.enabled;
      default:
        return NfcStatus.notSupported;
    }
  }

  @override
  Future<void> connect({
    Duration? timeout,
    String iosAlertMessage = 'Hold your iPhone near the biometric Passport',
  }) async {
    if (isConnected()) return;

    try {
      _tag = await FlutterNfcKit.poll(
        timeout: timeout ?? this.timeout,
        iosAlertMessage: iosAlertMessage,
        readIso14443A: true,
        readIso14443B: true,
        readIso18092: false,
        readIso15693: false,
        androidCheckNDEF: false,
        androidPlatformSound: false,
      );
      if (_tag!.type != NFCTagType.iso7816) {
        _log.info('Ignoring non ISO-7816 tag: ${_tag!.type}');
        return await disconnect();
      }
    } on Exception catch (e) {
      throw NfcProviderError.fromException(e);
    }
  }

  @override
  Future<void> disconnect({
    String? iosAlertMessage,
    String? iosErrorMessage,
  }) async {
    if (isConnected()) {
      _log.fine('Disconnecting');
      try {
        _tag = null;
        return await FlutterNfcKit.finish(
          iosAlertMessage: iosAlertMessage,
          iosErrorMessage: iosErrorMessage,
        );
      } on Exception catch (e) {
        throw NfcProviderError.fromException(e);
      }
    }
  }

  @override
  bool isConnected() => _tag != null;

  @override
  Future<Uint8List> transceive(
    final Uint8List data, {
    Duration? timeout,
  }) async {
    try {
      return await FlutterNfcKit.transceive(
        data,
        timeout: timeout ?? this.timeout,
      );
    } on Exception catch (e) {
      throw NfcProviderError.fromException(e);
    }
  }
}
