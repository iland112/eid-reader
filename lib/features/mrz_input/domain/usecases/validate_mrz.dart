import '../entities/mrz_data.dart';

/// Validates MRZ input data according to ICAO 9303.
class ValidateMrz {
  /// Returns null if valid, or an error message string if invalid.
  String? validateDocumentNumber(String value) {
    if (value.isEmpty) return 'Document number is required';
    if (value.length > 9) return 'Maximum 9 characters';
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
      return 'Only letters and digits allowed';
    }
    return null;
  }

  /// Validates date in YYMMDD format.
  String? validateDate(String value, {String fieldName = 'Date'}) {
    if (value.isEmpty) return '$fieldName is required';
    if (value.length != 6) return 'Format: YYMMDD (6 digits)';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'Only digits allowed';
    }

    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4, 6));

    if (month < 1 || month > 12) return 'Invalid month';
    if (day < 1 || day > 31) return 'Invalid day';

    return null;
  }

  /// Validates complete MRZ data. Returns null if valid.
  String? validate(MrzData data) {
    final docError = validateDocumentNumber(data.documentNumber);
    if (docError != null) return 'Document number: $docError';

    final dobError = validateDate(data.dateOfBirth, fieldName: 'Date of birth');
    if (dobError != null) return dobError;

    final doeError = validateDate(data.dateOfExpiry, fieldName: 'Date of expiry');
    if (doeError != null) return doeError;

    return null;
  }
}
