/// Enhanced OCR character correction for ICAO 9303 MRZ lines.
///
/// Uses position-aware confusion matrices to correct common OCR
/// misrecognition between visually similar characters (O/0, I/1, etc.).
class MrzOcrCorrector {
  /// Corrects Line 1 characters (all alpha/filler context).
  ///
  /// TD3 Line 1: document type, issuing state, name fields.
  /// No digit positions exist in Line 1.
  String correctLine1(String line) {
    final buffer = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      var c = line[i];
      if (c != '<') {
        c = _digitToAlpha(c);
      }
      buffer.write(c);
    }
    var result = buffer.toString();

    // In name field (positions 5+), clean up filler misrecognition.
    // OCR commonly reads '<' as 'K', 'X', 'V', 'N', etc.
    if (result.length > 5) {
      final prefix = result.substring(0, 5);
      var nameField = result.substring(5);

      // Phase 0: Convert trailing K-run to fillers.
      // OCR often reads trailing '<' as 'K'. Convert consecutive Ks
      // from the end, stopping at any non-K character (including '<').
      // This handles the all-K case (BAEKKKK → BAE<<<<) while
      // preserving names when fillers are already correctly read
      // (BAEK<<<< stays unchanged because < stops the scan).
      final chars = nameField.split('');
      for (int i = chars.length - 1; i >= 0; i--) {
        if (chars[i] == 'K') {
          chars[i] = '<';
        } else {
          break;
        }
      }
      nameField = chars.join();

      // Pass 1: Replace runs of 3+ identical non-< chars with fillers
      // (e.g. XXXXXX → <<<<<<). Real names don't repeat 3+ times.
      nameField = nameField.replaceAllMapped(
        RegExp(r'([^<])\1{2,}'),
        (m) => '<' * m.group(0)!.length,
      );

      // Pass 2: Replace isolated single non-< char surrounded by fillers
      // (e.g. ...<<<K → ...<<<< at end, or <<<K<<< → <<<<<<<)
      nameField = nameField.replaceAllMapped(
        RegExp(r'(?<=<{2})[^<](?=<{2}|$)'),
        (m) => '<',
      );

      // Pass 3: Replace K (most common '<' misread) between fillers.
      // Handles patterns like <K<, <KK<, <K<K<K< that Passes 1-2 miss.
      nameField = nameField.replaceAllMapped(
        RegExp(r'(?<=<)K+(?=<|$)'),
        (m) => '<' * m.group(0)!.length,
      );

      result = prefix + nameField;
    }

    return result;
  }

  /// Corrects Line 2 characters using position-specific context.
  ///
  /// TD3 Line 2 positions:
  /// [0-8]   Document number (alphanumeric)
  /// [9]     Check digit (digit)
  /// [10-12] Nationality (alpha)
  /// [13-18] Date of birth (digit)
  /// [19]    Check digit (digit)
  /// [20]    Sex (alpha: M/F/<)
  /// [21-26] Date of expiry (digit)
  /// [27]    Check digit (digit)
  /// [28-42] Optional data (alphanumeric)
  /// [43]    Overall check digit (digit)
  String correctLine2(String line) {
    final buffer = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      var c = line[i];
      if (_isDigitPosition(i)) {
        c = _alphaToDigit(c);
      } else if (_isAlphaPosition(i)) {
        c = _digitToAlpha(c);
      }
      // Alphanumeric positions (0-8, 28-42): no correction
      buffer.write(c);
    }
    return buffer.toString();
  }

  /// Converts digit characters to their visually similar alpha equivalent.
  String _digitToAlpha(String c) {
    return switch (c) {
      '0' => 'O',
      '1' => 'I',
      '8' => 'B',
      '5' => 'S',
      '2' => 'Z',
      '6' => 'G',
      '7' => 'T',
      _ => c,
    };
  }

  /// Converts alpha characters to their visually similar digit equivalent.
  String _alphaToDigit(String c) {
    return switch (c) {
      'O' || 'Q' || 'D' => '0',
      'I' || 'l' || 'L' => '1',
      'S' => '5',
      'Z' => '2',
      'B' => '8',
      'G' => '6',
      'T' => '7',
      _ => c,
    };
  }

  /// Returns true if position i in Line 2 must be a digit.
  bool _isDigitPosition(int i) {
    if (i == 9 || i == 19 || i == 27 || i == 43) return true;
    if (i >= 13 && i <= 18) return true;
    if (i >= 21 && i <= 26) return true;
    return false;
  }

  /// Returns true if position i in Line 2 must be alpha.
  bool _isAlphaPosition(int i) {
    if (i >= 10 && i <= 12) return true;
    if (i == 20) return true;
    return false;
  }
}
