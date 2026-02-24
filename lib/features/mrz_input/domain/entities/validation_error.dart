/// MRZ validation error types.
///
/// Returned by [ValidateMrz] instead of raw strings so that
/// the presentation layer can resolve localized messages via
/// [AppLocalizations].
enum MrzValidationError {
  docNumberRequired,
  docNumberMaxLength,
  docNumberInvalidChars,
  dateRequired,
  dateFormat,
  dateDigitsOnly,
  invalidMonth,
  invalidDay,
}
