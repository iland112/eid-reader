/// Classified passport reading errors.
///
/// Used instead of raw error message strings so that the
/// presentation layer can resolve localized messages via
/// [AppLocalizations].
enum PassportReadError {
  tagLost,
  authFailed,
  passportNotDetected,
  timeout,
  nfcError,
  nfcNotSupported,
  nfcDisabled,
  generic,
}
