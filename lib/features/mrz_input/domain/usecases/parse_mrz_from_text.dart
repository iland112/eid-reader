import '../../../../core/utils/mrz_utils.dart';
import '../entities/mrz_data.dart';
import 'mrz_ocr_corrector.dart';

/// Parses ICAO 9303 TD3 (passport) MRZ from raw OCR text.
///
/// TD3 format: 2 lines of 44 characters each.
/// Line 1: document type, issuing state, name
/// Line 2: document number, DOB, sex, expiry, optional data, check digits
class ParseMrzFromText {
  static final _mrzLinePattern = RegExp(r'^[A-Z0-9<]{44}$');
  static final _line1Pattern = RegExp(r'^P[A-Z<]{43}$');

  final MrzOcrCorrector _corrector = MrzOcrCorrector();

  /// Parses OCR text and extracts MRZ data.
  /// Returns null if no valid MRZ is found.
  MrzData? parse(String ocrText) {
    final lines = _findMrzLines(ocrText);
    if (lines == null) return null;

    final line1 = lines.$1;
    final line2 = lines.$2;

    final line2Data = _extractFromLine2(line2);
    if (line2Data == null) return null;

    final line1Data = _extractFromLine1(line1);

    return MrzData(
      documentNumber: line2Data.documentNumber,
      dateOfBirth: line2Data.dateOfBirth,
      dateOfExpiry: line2Data.dateOfExpiry,
      mrzLine1: line1,
      mrzLine2: line2,
      documentType: line1Data?.documentType,
      issuingState: line1Data?.issuingState,
      surname: line1Data?.surname,
      givenNames: line1Data?.givenNames,
      nationality: line2Data.nationality,
      sex: line2Data.sex,
    );
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

      // Apply OCR error correction
      final c1Corrected = _corrector.correctLine1(c1);
      final c2Corrected = _corrector.correctLine2(c2);

      if (_line1Pattern.hasMatch(c1Corrected) &&
          _mrzLinePattern.hasMatch(c2Corrected)) {
        return (c1Corrected, c2Corrected);
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

  /// Extracts fields from Line 1 of TD3 format.
  ///
  /// TD3 Line 1 layout (44 chars):
  /// [0-1]  Document type (e.g., "P<")
  /// [2-4]  Issuing state (3 chars)
  /// [5-43] Name: SURNAME<<GIVEN<NAMES<<<<...
  ({String documentType, String issuingState, String surname, String givenNames})?
  _extractFromLine1(String line1) {
    if (line1.length != 44) return null;

    final docType = line1.substring(0, 2).replaceAll('<', '').trim();
    final issuingState = line1.substring(2, 5).replaceAll('<', '').trim();
    final nameField = line1.substring(5);

    // ICAO 9303: surname and given names separated by <<
    final nameParts = nameField.split('<<');
    final surname = nameParts[0].replaceAll('<', ' ').trim();
    final givenNames = nameParts.length > 1
        ? nameParts.sublist(1).join(' ').replaceAll('<', ' ').trim()
        : '';

    if (docType.isEmpty) return null;

    return (
      documentType: docType,
      issuingState: issuingState,
      surname: surname,
      givenNames: givenNames,
    );
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
  ({
    String documentNumber,
    String dateOfBirth,
    String dateOfExpiry,
    String nationality,
    String sex,
  })? _extractFromLine2(String line2) {
    if (line2.length != 44) return null;

    // Extract fields
    final docNumberRaw = line2.substring(0, 9);
    final docNumberCheckDigit = int.tryParse(line2[9]);
    final nationality = line2.substring(10, 13).replaceAll('<', '').trim();
    final dateOfBirth = line2.substring(13, 19);
    final dobCheckDigit = int.tryParse(line2[19]);
    final sex = line2[20];
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

    return (
      documentNumber: documentNumber,
      dateOfBirth: dateOfBirth,
      dateOfExpiry: dateOfExpiry,
      nationality: nationality,
      sex: sex == '<' ? '' : sex,
    );
  }
}
