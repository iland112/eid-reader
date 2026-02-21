import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/usecases/mrz_ocr_corrector.dart';

void main() {
  late MrzOcrCorrector corrector;

  setUp(() {
    corrector = MrzOcrCorrector();
  });

  group('MrzOcrCorrector Line 1', () {
    test('corrects 0 to O in alpha context', () {
      const input = 'P<UT0D0E<<J0HN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result.contains('0'), isFalse);
      expect(result.substring(2, 5), 'UTO');
    });

    test('corrects 1 to I in alpha context', () {
      const input = 'P<UTOER1KSSON<<ANNA<MAR1A<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result.contains('ERIKSSON'), isTrue);
      expect(result.contains('MARIA'), isTrue);
    });

    test('corrects 8 to B in alpha context', () {
      const input = 'P<G8RDOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result.substring(2, 5), 'GBR');
    });

    test('corrects 5 to S in alpha context', () {
      const input = 'P<UTOERIK55ON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result.contains('ERIKSSON'), isTrue);
    });

    test('corrects 2 to Z in alpha context', () {
      const input = 'P<UTOERI2SSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      // Actually 2 -> Z, so ERIZSSON
      expect(result.contains('2'), isFalse);
    });

    test('corrects 6 to G in alpha context', () {
      const input = 'P<6BRDOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result.substring(2, 5), 'GBR');
    });

    test('corrects 7 to T in alpha context', () {
      const input = 'P<U7ODOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result.substring(2, 5), 'UTO');
    });

    test('preserves filler characters', () {
      const input = 'P<UTODOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result, input);
    });

    test('does not change valid alpha input', () {
      const input = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result, input);
    });
  });

  group('MrzOcrCorrector Line 2', () {
    test('corrects alpha to digit in check digit positions', () {
      // Position 9 is check digit: O → 0
      const input = 'L898902C<OUTO6908061F9406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result[9], '0');
    });

    test('corrects alpha to digit in DOB positions (13-18)', () {
      // 'G' at position 13 → '6'
      const input = 'L898902C<3UTOG908061F9406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result[13], '6');
    });

    test('corrects alpha to digit in DOE positions (21-26)', () {
      // 'S' at position 21 → '5'
      const input = 'L898902C<3UTO6908061FS406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result[21], '5');
    });

    test('corrects digit to alpha in nationality (10-12)', () {
      // '0' at position 10 → 'O'
      const input = 'L898902C<30TO6908061F9406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result.substring(10, 13), 'OTO');
    });

    test('corrects digit to alpha in sex position (20)', () {
      // '6' at position 20 → 'G' (hypothetical)
      const input = 'L898902C<3UTO690806169406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result[20], 'G');
    });

    test('does not correct alphanumeric positions (0-8)', () {
      // Document number is alphanumeric, should not be corrected
      const input = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result.substring(0, 9), 'L898902C<');
    });

    test('does not correct optional data positions (28-42)', () {
      // Optional data is alphanumeric, should not be corrected
      const input = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result.substring(28, 43), 'ZE184226B<<<<<1');
    });

    test('corrects O to 0 in overall check digit position (43)', () {
      const input = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<1O';
      final result = corrector.correctLine2(input);
      expect(result[43], '0');
    });

    test('preserves valid Line 2', () {
      const input = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result, input);
    });

    test('corrects D to 0 in digit context', () {
      // Position 19 (DOB check digit): D → 0
      const input = 'L898902C<3UTO690806DF9406236ZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result[19], '0');
    });

    test('corrects T to 7 in digit context', () {
      // Position 27 (DOE check digit): T → 7
      const input = 'L898902C<3UTO6908061F940623TZE184226B<<<<<14';
      final result = corrector.correctLine2(input);
      expect(result[27], '7');
    });
  });
}
