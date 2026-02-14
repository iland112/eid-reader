/// ICAO 9303 MRZ check digit calculation.
class MrzUtils {
  static const _weights = [7, 3, 1];

  /// Calculates the ICAO 9303 check digit for the given string.
  static int calculateCheckDigit(String input) {
    int sum = 0;
    for (int i = 0; i < input.length; i++) {
      final c = input[i];
      int value;
      if (c == '<') {
        value = 0;
      } else if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
        // 0-9
        value = c.codeUnitAt(0) - 48;
      } else if (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) {
        // A-Z
        value = c.codeUnitAt(0) - 55;
      } else {
        value = 0;
      }
      sum += value * _weights[i % 3];
    }
    return sum % 10;
  }
}
