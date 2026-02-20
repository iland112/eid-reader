import '../../../../core/utils/mrz_utils.dart';
import '../entities/mrz_data.dart';

/// Parses ICAO 9303 TD3 (passport) MRZ from raw OCR text.
///
/// TD3 format: 2 lines of 44 characters each.
/// Line 1: document type, issuing state, name
/// Line 2: document number, DOB, sex, expiry, optional data, check digits
class ParseMrzFromText {
  static final _mrzLinePattern = RegExp(r'^[A-Z0-9<]{44}$');
  static final _line1Pattern = RegExp(r'^P[A-Z<]{43}$');

  /// Parses OCR text and extracts MRZ data.
  /// Returns null if no valid MRZ is found.
  MrzData? parse(String ocrText) {
    final lines = _findMrzLines(ocrText);
    if (lines == null) return null;

    final line2 = lines.$2;
    return _extractFromLine2(line2);
  }

  /// Finds the two MRZ lines from OCR text.
  /// Returns (line1, line2) or null if not found.
  (String, String)? _findMrzLines(String text) {
    // Normalize: replace common OCR mistakes and split into lines
    final normalized = text
        .toUpperCase()
        .replaceAll('«', '<')
        .replaceAll(' ', '');

    final rawLines = normalized.split(RegExp(r'[\n\r]+'));

    // Find consecutive lines matching MRZ pattern
    for (int i = 0; i < rawLines.length - 1; i++) {
      final candidate1 = _cleanLine(rawLines[i]);
      final candidate2 = _cleanLine(rawLines[i + 1]);

      if (candidate1.length == 44 &&
          candidate2.length == 44 &&
          _line1Pattern.hasMatch(candidate1) &&
          _mrzLinePattern.hasMatch(candidate2)) {
        return (candidate1, candidate2);
      }
    }

    return null;
  }

  /// Cleans a single line for MRZ matching.
  String _cleanLine(String line) {
    // Remove whitespace and common OCR artifacts
    return line
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('«', '<');
  }

  /// Extracts MRZ fields from line 2 of TD3 format.
  ///
  /// TD3 Line 2 layout (44 chars):
  /// [0-8]   Document number (9 chars)
  /// [9]     Check digit for document number
  /// [10-12] Nationality (3 chars)
  /// [13-18] Date of birth YYMMDD (6 chars)
  /// [19]    Check digit for DOB
  /// [20]    Sex (M/F/<)
  /// [21-26] Date of expiry YYMMDD (6 chars)
  /// [27]    Check digit for expiry
  /// [28-42] Optional data (15 chars)
  /// [43]    Overall check digit
  MrzData? _extractFromLine2(String line2) {
    if (line2.length != 44) return null;

    // Extract fields
    final docNumberRaw = line2.substring(0, 9);
    final docNumberCheckDigit = int.tryParse(line2[9]);
    final dateOfBirth = line2.substring(13, 19);
    final dobCheckDigit = int.tryParse(line2[19]);
    final dateOfExpiry = line2.substring(21, 27);
    final doeCheckDigit = int.tryParse(line2[27]);

    // Validate check digits
    if (docNumberCheckDigit == null ||
        dobCheckDigit == null ||
        doeCheckDigit == null) {
      return null;
    }

    if (MrzUtils.calculateCheckDigit(docNumberRaw) != docNumberCheckDigit) {
      return null;
    }
    if (MrzUtils.calculateCheckDigit(dateOfBirth) != dobCheckDigit) {
      return null;
    }
    if (MrzUtils.calculateCheckDigit(dateOfExpiry) != doeCheckDigit) {
      return null;
    }

    // Clean document number: remove trailing fillers
    final documentNumber = docNumberRaw.replaceAll(RegExp(r'<+$'), '');

    // Validate dates are numeric
    if (!RegExp(r'^[0-9]{6}$').hasMatch(dateOfBirth)) return null;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(dateOfExpiry)) return null;
    if (documentNumber.isEmpty) return null;

    return MrzData(
      documentNumber: documentNumber,
      dateOfBirth: dateOfBirth,
      dateOfExpiry: dateOfExpiry,
    );
  }
}
