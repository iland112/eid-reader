import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/core/utils/icao_codes.dart';

void main() {
  group('IcaoCodes', () {
    test('recognizes valid state codes', () {
      expect(IcaoCodes.isValidStateCode('USA'), isTrue);
      expect(IcaoCodes.isValidStateCode('KOR'), isTrue);
      expect(IcaoCodes.isValidStateCode('GBR'), isTrue);
      expect(IcaoCodes.isValidStateCode('JPN'), isTrue);
      expect(IcaoCodes.isValidStateCode('DEU'), isTrue);
    });

    test('rejects invalid state codes', () {
      expect(IcaoCodes.isValidStateCode('XYZ'), isFalse);
      expect(IcaoCodes.isValidStateCode('ZZZ'), isFalse);
      expect(IcaoCodes.isValidStateCode('ABC'), isFalse);
    });

    test('is case-insensitive', () {
      expect(IcaoCodes.isValidStateCode('usa'), isTrue);
      expect(IcaoCodes.isValidStateCode('Kor'), isTrue);
    });

    test('recognizes UTO test code', () {
      expect(IcaoCodes.isValidStateCode('UTO'), isTrue);
    });

    test('corrects single-char OCR error to valid code', () {
      // G8R → GBR (8→B)
      expect(IcaoCodes.correctStateCode('G8R'), 'GBR');
    });

    test('corrects 0 to O in state code', () {
      // K0R → KOR (0→O)
      expect(IcaoCodes.correctStateCode('K0R'), 'KOR');
    });

    test('returns null for uncorrectable code', () {
      expect(IcaoCodes.correctStateCode('ZZZ'), isNull);
    });

    test('returns valid code unchanged', () {
      expect(IcaoCodes.correctStateCode('USA'), 'USA');
    });

    test('returns null for ambiguous correction', () {
      // A code that could correct to multiple valid codes
      // This depends on the actual code set; verify behavior
      final result = IcaoCodes.correctStateCode('X0X');
      // Should be null because no single correction is unambiguous
      expect(result, isNull);
    });

    test('returns null for wrong length', () {
      expect(IcaoCodes.correctStateCode('US'), isNull);
      expect(IcaoCodes.correctStateCode(''), isNull);
      expect(IcaoCodes.correctStateCode('USAA'), isNull);
    });
  });
}
