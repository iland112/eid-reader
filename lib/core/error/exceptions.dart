/// NFC is not available on this device.
class NfcNotAvailableException implements Exception {
  final String message;
  const NfcNotAvailableException([this.message = 'NFC is not available']);

  @override
  String toString() => 'NfcNotAvailableException: $message';
}

/// NFC is supported but currently disabled.
class NfcDisabledException implements Exception {
  final String message;
  const NfcDisabledException([this.message = 'NFC is disabled']);

  @override
  String toString() => 'NfcDisabledException: $message';
}

/// NFC tag was lost during communication.
class TagLostException implements Exception {
  final String message;
  const TagLostException([this.message = 'NFC tag connection lost']);

  @override
  String toString() => 'TagLostException: $message';
}

/// BAC or PACE authentication failed.
class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException([this.message = 'Authentication failed']);

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Passport reading timed out.
class ReadTimeoutException implements Exception {
  final String message;
  const ReadTimeoutException([this.message = 'Reading timed out']);

  @override
  String toString() => 'ReadTimeoutException: $message';
}
