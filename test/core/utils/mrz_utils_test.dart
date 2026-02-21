import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/core/utils/mrz_utils.dart';

void main() {
  group('MrzUtils.calculateCheckDigit', () {
    test('ICAO example: L898902C -> 3', () {
      expect(MrzUtils.calculateCheckDigit('L898902C'), 3);
    });

    test('ICAO example: 690806 -> 1', () {
      expect(MrzUtils.calculateCheckDigit('690806'), 1);
    });

    test('ICAO example: 940623 -> 6', () {
      expect(MrzUtils.calculateCheckDigit('940623'), 6);
    });

    test('all filler characters return 0', () {
      expect(MrzUtils.calculateCheckDigit('<<<<<<'), 0);
    });

    test('empty string returns 0', () {
      expect(MrzUtils.calculateCheckDigit(''), 0);
    });

    test('applies weights 7,3,1 cyclically', () {
      // A=10, B=11, C=12
      // sum = 10*7 + 11*3 + 12*1 = 70 + 33 + 12 = 115
      // 115 % 10 = 5
      expect(MrzUtils.calculateCheckDigit('ABC'), 5);
    });

    test('single digit', () {
      // '9' = 9, weight 7 -> 63 % 10 = 3
      expect(MrzUtils.calculateCheckDigit('9'), 3);
    });

    test('single letter A', () {
      // 'A' = 10, weight 7 -> 70 % 10 = 0
      expect(MrzUtils.calculateCheckDigit('A'), 0);
    });

    test('mixed alphanumeric with filler', () {
      // 'A1<' -> A=10*7=70, 1=1*3=3, <=0*1=0 -> 73 % 10 = 3
      expect(MrzUtils.calculateCheckDigit('A1<'), 3);
    });
  });

  group('MrzUtils.formatDisplayDate', () {
    test('formats YYMMDD as DD MMM YYYY', () {
      expect(MrzUtils.formatDisplayDate('940623'), '23 Jun 1994');
    });

    test('formats 2000s date', () {
      expect(MrzUtils.formatDisplayDate('050315'), '15 Mar 2005');
    });

    test('pads single-digit day', () {
      expect(MrzUtils.formatDisplayDate('900106'), '06 Jan 1990');
    });

    test('returns raw string for invalid length', () {
      expect(MrzUtils.formatDisplayDate('12345'), '12345');
      expect(MrzUtils.formatDisplayDate(''), '');
    });

    test('returns raw string for non-numeric input', () {
      expect(MrzUtils.formatDisplayDate('ABCDEF'), 'ABCDEF');
    });

    test('isDob shifts future dates back 100 years', () {
      // 690806 → 2069 (70-year pivot), but isDob shifts to 1969
      expect(
        MrzUtils.formatDisplayDate('690806', isDob: true),
        '06 Aug 1969',
      );
    });

    test('isDob keeps past dates unchanged', () {
      // 900115 → 1990 (already in the past)
      expect(
        MrzUtils.formatDisplayDate('900115', isDob: true),
        '15 Jan 1990',
      );
    });

    test('DOE without isDob keeps future dates', () {
      // 350315 → 2035 (valid expiry date)
      expect(MrzUtils.formatDisplayDate('350315'), '15 Mar 2035');
    });
  });
}
