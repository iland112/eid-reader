import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction for platform-specific screen security features.
///
/// On Android: enables/disables FLAG_SECURE to prevent screenshots
/// and screen recording of sensitive passport data.
abstract class SecureScreenService {
  /// Enables secure mode (e.g. FLAG_SECURE on Android).
  Future<void> enableSecureMode();

  /// Disables secure mode.
  Future<void> disableSecureMode();
}

/// Android implementation using MethodChannel.
class SecureScreenServiceImpl implements SecureScreenService {
  static const _channel =
      MethodChannel('com.smartcoreinc.eid_reader/secure_screen');

  @override
  Future<void> enableSecureMode() async {
    await _channel.invokeMethod<void>('enableSecureMode');
  }

  @override
  Future<void> disableSecureMode() async {
    await _channel.invokeMethod<void>('disableSecureMode');
  }
}

final secureScreenServiceProvider = Provider<SecureScreenService>((ref) {
  return SecureScreenServiceImpl();
});
