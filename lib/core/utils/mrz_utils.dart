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

  /// Formats a YYMMDD string for display as "DD MMM YYYY" (e.g. "06 Aug 1969").
  ///
  /// When [isDob] is true, dates that fall in the future are shifted back
  /// 100 years (a date of birth is always in the past).
  /// Returns the raw string unchanged if it cannot be parsed.
  static String formatDisplayDate(String yymmdd, {bool isDob = false}) {
    if (yymmdd.length != 6) return yymmdd;
    try {
      var date = parseYYMMDD(yymmdd);
      if (isDob && date.isAfter(DateTime.now())) {
        date = DateTime(date.year - 100, date.month, date.day);
      }
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final d = date.day.toString().padLeft(2, '0');
      final m = months[date.month - 1];
      return '$d $m ${date.year}';
    } catch (_) {
      return yymmdd;
    }
  }

  /// Formats a YYMMDD string with localized month abbreviations.
  ///
  /// [monthAbbreviations] must contain 12 entries (Jan–Dec equivalent).
  /// Returns the raw string unchanged if it cannot be parsed.
  static String formatDisplayDateLocalized(
    String yymmdd, {
    bool isDob = false,
    required List<String> monthAbbreviations,
  }) {
    if (yymmdd.length != 6) return yymmdd;
    try {
      var date = parseYYMMDD(yymmdd);
      if (isDob && date.isAfter(DateTime.now())) {
        date = DateTime(date.year - 100, date.month, date.day);
      }
      final d = date.day.toString().padLeft(2, '0');
      final m = monthAbbreviations[date.month - 1];
      return '$d $m ${date.year}';
    } catch (_) {
      return yymmdd;
    }
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
