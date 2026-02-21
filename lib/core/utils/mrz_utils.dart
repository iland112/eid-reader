/// ICAO 9303 MRZ utilities.
class MrzUtils {
  static const _weights = [7, 3, 1];

  /// Formats a DateTime to YYMMDD string.
  static String formatYYMMDD(DateTime date) {
    final y = (date.year % 100).toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// Parses a YYMMDD string to DateTime (70-year pivot: 00-69 → 2000s, 70-99 → 1900s).
  static DateTime parseYYMMDD(String yymmdd) {
    final yy = int.parse(yymmdd.substring(0, 2));
    final mm = int.parse(yymmdd.substring(2, 4));
    final dd = int.parse(yymmdd.substring(4, 6));
    final year = yy < 70 ? 2000 + yy : 1900 + yy;
    return DateTime(year, mm, dd);
  }

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
