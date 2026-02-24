import '../entities/mrz_data.dart';
import '../entities/validation_error.dart';

/// Validates MRZ input data according to ICAO 9303.
class ValidateMrz {
  /// Returns null if valid, or an error enum if invalid.
  MrzValidationError? validateDocumentNumber(String value) {
    if (value.isEmpty) return MrzValidationError.docNumberRequired;
    if (value.length > 9) return MrzValidationError.docNumberMaxLength;
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
      return MrzValidationError.docNumberInvalidChars;
    }
    return null;
  }

  /// Validates date in YYMMDD format.
  MrzValidationError? validateDate(String value) {
    if (value.isEmpty) return MrzValidationError.dateRequired;
    if (value.length != 6) return MrzValidationError.dateFormat;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return MrzValidationError.dateDigitsOnly;
    }

    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4, 6));

    if (month < 1 || month > 12) return MrzValidationError.invalidMonth;
    if (day < 1 || day > 31) return MrzValidationError.invalidDay;

    return null;
  }

  /// Validates complete MRZ data. Returns null if valid.
  MrzValidationError? validate(MrzData data) {
    final docError = validateDocumentNumber(data.documentNumber);
    if (docError != null) return docError;

    final dobError = validateDate(data.dateOfBirth);
    if (dobError != null) return dobError;

    final doeError = validateDate(data.dateOfExpiry);
    if (doeError != null) return doeError;

    return null;
  }
}
