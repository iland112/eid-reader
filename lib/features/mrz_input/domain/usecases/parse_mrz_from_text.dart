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

    // Clean all lines and filter candidates (length 42-46 to allow OCR variance)
    final candidates = <String>[];
    for (final raw in rawLines) {
      final cleaned = _cleanLine(raw);
      if (cleaned.length >= 42 && cleaned.length <= 46) {
        candidates.add(cleaned);
      }
    }

    // Try consecutive candidates (may skip blank lines from OCR)
    for (int i = 0; i < candidates.length - 1; i++) {
      // Trim or pad to exactly 44 characters
      final c1 = _normalizeLength(candidates[i]);
      final c2 = _normalizeLength(candidates[i + 1]);

      if (c1 == null || c2 == null) continue;

      // Apply OCR error correction on line 2 (digit/alpha context)
      final c2Corrected = _correctOcrErrors(c2);

      if (_line1Pattern.hasMatch(c1) &&
          _mrzLinePattern.hasMatch(c2Corrected)) {
        return (c1, c2Corrected);
      }
    }

    return null;
  }

  /// Normalize a candidate line to exactly 44 characters.
  /// Trims trailing noise or returns null if too far off.
  String? _normalizeLength(String line) {
    if (line.length == 44) return line;
    if (line.length > 44 && line.length <= 46) {
      // Try trimming trailing characters (OCR noise)
      return line.substring(0, 44);
    }
    if (line.length >= 42 && line.length < 44) {
      // Too short, pad with fillers (some OCR drops trailing <)
      return line.padRight(44, '<');
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

  /// Applies common OCR character corrections for MRZ text.
  /// MRZ uses OCR-B font; ML Kit often misreads these characters.
  String _correctOcrErrors(String line) {
    final buffer = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      var c = line[i];
      // Common OCR-B misreads
      if (c == 'O' && _isDigitContext(line, i)) c = '0';
      if (c == 'Q' && _isDigitContext(line, i)) c = '0';
      if (c == 'I' && _isDigitContext(line, i)) c = '1';
      if (c == 'l' || c == 'L' && _isDigitContext(line, i)) {
        c = '1';
      }
      if (c == 'S' && _isDigitContext(line, i)) c = '5';
      if (c == 'Z' && _isDigitContext(line, i)) c = '2';
      if (c == 'B' && _isDigitContext(line, i)) c = '8';
      if (c == 'G' && _isDigitContext(line, i)) c = '6';
      if (c == 'D' && _isDigitContext(line, i)) c = '0';
      // Reverse: digit in alpha context
      if (c == '0' && _isAlphaContext(line, i)) c = 'O';
      if (c == '1' && _isAlphaContext(line, i)) c = 'I';
      if (c == '8' && _isAlphaContext(line, i)) c = 'B';
      buffer.write(c);
    }
    return buffer.toString();
  }

  /// Returns true if position i in MRZ line 2 is expected to be a digit.
  /// TD3 Line 2: positions 9, 13-19, 21-27, 43 are digits/check digits.
  bool _isDigitContext(String line, int i) {
    if (line.length != 44) return false;
    // Check digit positions
    if (i == 9 || i == 19 || i == 27 || i == 43) return true;
    // Date of birth (13-18) and date of expiry (21-26)
    if (i >= 13 && i <= 18) return true;
    if (i >= 21 && i <= 26) return true;
    return false;
  }

  /// Returns true if position i in MRZ line 1 is expected to be alpha.
  /// TD3 Line 1: all positions are alpha or filler (<).
  bool _isAlphaContext(String line, int i) {
    if (line.length != 44) return false;
    // Nationality (10-12) is always alpha
    if (i >= 10 && i <= 12) return true;
    return false;
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
