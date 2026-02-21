import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/passport_reader/domain/entities/mrz_field_comparison.dart';

void main() {
  group('MrzFieldMatch', () {
    test('stores field comparison data', () {
      const match = MrzFieldMatch(
        fieldName: 'Document Number',
        ocrValue: 'L898902C',
        chipValue: 'L898902C',
        matches: true,
      );
      expect(match.fieldName, 'Document Number');
      expect(match.ocrValue, 'L898902C');
      expect(match.chipValue, 'L898902C');
      expect(match.matches, isTrue);
    });

    test('two instances with same values are equal', () {
      const a = MrzFieldMatch(
        fieldName: 'Surname',
        ocrValue: 'DOE',
        chipValue: 'DOE',
        matches: true,
      );
      const b = MrzFieldMatch(
        fieldName: 'Surname',
        ocrValue: 'DOE',
        chipValue: 'DOE',
        matches: true,
      );
      expect(a, equals(b));
    });

    test('instances with different values are not equal', () {
      const a = MrzFieldMatch(
        fieldName: 'Surname',
        ocrValue: 'DOE',
        chipValue: 'DOE',
        matches: true,
      );
      const b = MrzFieldMatch(
        fieldName: 'Surname',
        ocrValue: 'SMITH',
        chipValue: 'DOE',
        matches: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('handles null ocrValue', () {
      const match = MrzFieldMatch(
        fieldName: 'Nationality',
        ocrValue: null,
        chipValue: 'USA',
        matches: false,
      );
      expect(match.ocrValue, isNull);
      expect(match.matches, isFalse);
    });
  });

  group('MrzFieldComparisonResult', () {
    test('allMatch returns true when all fields match', () {
      const result = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Document Number',
          ocrValue: 'L898902C',
          chipValue: 'L898902C',
          matches: true,
        ),
        MrzFieldMatch(
          fieldName: 'Date of Birth',
          ocrValue: '690806',
          chipValue: '690806',
          matches: true,
        ),
      ]);
      expect(result.allMatch, isTrue);
      expect(result.matchCount, 2);
      expect(result.totalFields, 2);
    });

    test('allMatch returns false when some fields mismatch', () {
      const result = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Document Number',
          ocrValue: 'L898902C',
          chipValue: 'L898902C',
          matches: true,
        ),
        MrzFieldMatch(
          fieldName: 'Surname',
          ocrValue: 'DOE',
          chipValue: 'SMITH',
          matches: false,
        ),
      ]);
      expect(result.allMatch, isFalse);
      expect(result.matchCount, 1);
      expect(result.totalFields, 2);
    });

    test('equality compares by field matches', () {
      const a = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Document Number',
          ocrValue: 'ABC',
          chipValue: 'ABC',
          matches: true,
        ),
      ]);
      const b = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Document Number',
          ocrValue: 'ABC',
          chipValue: 'ABC',
          matches: true,
        ),
      ]);
      expect(a, equals(b));
    });

    test('empty fieldMatches means allMatch is true', () {
      const result = MrzFieldComparisonResult(fieldMatches: []);
      expect(result.allMatch, isTrue);
      expect(result.matchCount, 0);
      expect(result.totalFields, 0);
    });
  });
}
