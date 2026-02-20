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
}
