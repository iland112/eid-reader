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

    test('replaces runs of 3+ identical non-< chars with fillers', () {
      // KKKKKK in filler region → <<<<<<  (44 chars in, 44 chars out)
      const input  = 'P<KORJUNG<<KYUNG<BAE<<<<<<KKKKKK<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result, 'P<KORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<<');
      expect(result.length, 44);
    });

    test('replaces isolated single char surrounded by fillers', () {
      // X at end of line after <<< → < (isolated noise at end of string)
      const input  = 'P<UTODOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<X';
      final result = corrector.correctLine1(input);
      expect(result.contains('X'), isFalse);
      expect(result.length, 44);
    });

    test('preserves real double-letter names', () {
      // 'LL' in a name should NOT be replaced (only 3+ triggers)
      const input = 'P<UTOMCCALL<<JOHN<WILLIAM<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result.contains('LL'), isTrue);
    });

    test('cleans mixed filler noise from OCR', () {
      // Real-world: <<<<<<XXXXXX<<<<<<<<<<<<X → all fillers
      const input  = 'P<UTODOE<<JOHN<<<<<<<<<<<<XXXXXX<<<<<<<<<<<<X';
      final result = corrector.correctLine1(input);
      expect(result.contains('XXXXXX'), isFalse);
      expect(result.contains('X'), isFalse);
    });

    test('preserves document subtype per ICAO 9303 (position 1)', () {
      // ICAO 9303 Part 4 §4.2.2: Position 1 is at issuing State discretion.
      // Valid subtypes: P< (regular), PM (Korea), PD (diplomatic),
      // PO (official), PS (service), etc.

      // PM — Korean passport
      const inputPM = 'PMKORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<';
      final resultPM = corrector.correctLine1(inputPM);
      expect(resultPM[0], 'P');
      expect(resultPM[1], 'M');
      expect(resultPM.substring(2, 5), 'KOR');
      expect(resultPM, inputPM);

      // PD — Diplomatic passport
      const inputPD = 'PDGBRDOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final resultPD = corrector.correctLine1(inputPD);
      expect(resultPD[1], 'D');
      expect(resultPD.substring(2, 5), 'GBR');

      // PO — Official passport
      const inputPO = 'PODEUDOE<<JANE<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final resultPO = corrector.correctLine1(inputPO);
      expect(resultPO[1], 'O');

      // PS — Service passport
      const inputPS = 'PSFRADUPONT<<MARIE<<<<<<<<<<<<<<<<<<<<<<<<<';
      final resultPS = corrector.correctLine1(inputPS);
      expect(resultPS[1], 'S');

      // P< — Regular passport (filler preserved)
      const inputPC = 'P<KORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<';
      final resultPC = corrector.correctLine1(inputPC);
      expect(resultPC[1], '<');
      expect(resultPC, inputPC);
    });

    test('corrects digit in subtype position to alpha', () {
      // OCR might read PO as P0 (zero instead of O)
      const input = 'P0GBRDOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result[1], 'O'); // 0 → O via _digitToAlpha
      expect(result.substring(0, 2), 'PO');
    });

    test('replaces K between fillers (< misread as K)', () {
      // <K< pattern: K between fillers → filler
      const input  = 'P<KORJUNG<<KYUNG<BAE<<K<K<K<K<K<K<K<K<K<K<K<';
      final result = corrector.correctLine1(input);
      expect(result, 'P<KORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<<');
    });

    test('replaces KK between fillers', () {
      // <KK< pattern: consecutive Ks between fillers → fillers
      const input  = 'P<KORJUNG<<KYUNG<BAE<<KK<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result, 'P<KORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<');
    });

    test('preserves K in valid name positions', () {
      // K in KYUNG must not be replaced (middle of name, not trailing)
      const input = 'P<KORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result, input);
      expect(result.contains('KYUNG'), isTrue);
      expect(result.contains('JUNG'), isTrue);
    });

    test('handles mixed K and filler noise at end', () {
      // After Pass 1 (KKK→<<<), remaining K in filler region should be cleaned
      const input  = 'P<KORJUNG<<KYUNG<BAE<<KKKK<K<K<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result, 'P<KORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<');
    });

    test('converts trailing K fillers (< misread as K)', () {
      // Most common real-world case: OCR reads trailing < as K
      // Name is BAE, all trailing < read as K
      // 20 chars + 24 Ks = 44
      const input  = 'PMKORJUNG<<KYUNG<BAEKKKKKKKKKKKKKKKKKKKKKKKK';
      final result = corrector.correctLine1(input);
      // 20 chars + 24 <s = 44
      expect(result, 'PMKORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<<');
      expect(result.contains('BAE'), isTrue);
      expect(result.contains('KYUNG'), isTrue);
    });

    test('converts trailing K fillers with mixed <K< pattern', () {
      // OCR reads some < correctly and some as K
      const input  = 'PMKORJUNG<<KYUNG<BAE<<K<KKKKK<K<<<<<<<<<<<<<';
      final result = corrector.correctLine1(input);
      expect(result, 'PMKORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<<');
    });

    test('converts all-K trailing fillers for non-K-ending name', () {
      // Name ends with N (non-K), all trailing < as K
      const input  = 'P<UTODOE<<JOHNKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK';
      final result = corrector.correctLine1(input);
      // Phase 0 converts consecutive trailing Ks, stops at N
      expect(result, 'P<UTODOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<');
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
