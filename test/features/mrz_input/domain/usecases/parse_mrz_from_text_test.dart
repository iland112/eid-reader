import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/usecases/parse_mrz_from_text.dart';

void main() {
  late ParseMrzFromText parser;

  setUp(() {
    parser = ParseMrzFromText();
  });

  group('ParseMrzFromText', () {
    // ICAO 9303 example: document L898902C, DOB 690806, DOE 940623
    // Check digits: doc=3, DOB=1, DOE=6
    const validLine1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
    const validLine2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';

    test('parses valid TD3 MRZ text', () {
      final result = parser.parse('$validLine1\n$validLine2');

      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C');
      expect(result.dateOfBirth, '690806');
      expect(result.dateOfExpiry, '940623');
    });

    test('parses MRZ with surrounding text (OCR noise)', () {
      const ocrText = '''
Some random text above
$validLine1
$validLine2
More text below
''';
      final result = parser.parse(ocrText);

      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C');
    });

    test('returns null for empty text', () {
      expect(parser.parse(''), isNull);
    });

    test('returns null for single MRZ line', () {
      expect(parser.parse(validLine2), isNull);
    });

    test('returns null for non-MRZ text', () {
      expect(parser.parse('This is not an MRZ at all'), isNull);
    });

    test('returns null when check digit for document number is wrong', () {
      // Change doc number check digit from 3 to 0
      const badLine2 = 'L898902C<0UTO6908061F9406236ZE184226B<<<<<14';
      final result = parser.parse('$validLine1\n$badLine2');

      expect(result, isNull);
    });

    test('returns null when check digit for date of birth is wrong', () {
      // Change DOB check digit from 1 to 0
      const badLine2 = 'L898902C<3UTO6908060F9406236ZE184226B<<<<<14';
      final result = parser.parse('$validLine1\n$badLine2');

      expect(result, isNull);
    });

    test('returns null when check digit for date of expiry is wrong', () {
      // Change DOE check digit from 6 to 0
      const badLine2 = 'L898902C<3UTO6908061F9406230ZE184226B<<<<<14';
      final result = parser.parse('$validLine1\n$badLine2');

      expect(result, isNull);
    });

    test('trims trailing filler characters from document number', () {
      // Doc number: AB123<<<< (5 chars + 4 fillers = 9 chars)
      // calculateCheckDigit('AB123<<<<') = ?
      // We need to construct a valid line2 with check digit
      // A=10, B=11, 1=1, 2=2, 3=3, <=0, <=0, <=0, <=0
      // Weights: 7,3,1,7,3,1,7,3,1
      // 10*7=70, 11*3=33, 1*1=1, 2*7=14, 3*3=9, 0*1=0, 0*7=0, 0*3=0, 0*1=0
      // Sum = 70+33+1+14+9+0+0+0+0 = 127, 127%10 = 7
      const line2 = 'AB123<<<<7UTO6908061F9406236ZE184226B<<<<<14';
      final result = parser.parse('$validLine1\n$line2');

      expect(result, isNotNull);
      expect(result!.documentNumber, 'AB123');
    });

    test('handles document number without filler characters', () {
      final result = parser.parse('$validLine1\n$validLine2');

      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C');
    });

    test('handles « (guillemet) as filler character', () {
      final line1WithGuillemet = validLine1.replaceAll('<', '«');
      final line2WithGuillemet = validLine2.replaceAll('<', '«');
      final result =
          parser.parse('$line1WithGuillemet\n$line2WithGuillemet');

      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C');
    });

    test('handles blank lines between MRZ lines (OCR artifact)', () {
      // OCR may insert blank lines; parser collapses them and still finds MRZ
      final result = parser.parse('$validLine1\n\n$validLine2');

      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C');
    });

    test('parses when MRZ lines are not at start of text', () {
      const ocrText = 'PASSPORT\nUNITED STATES\n$validLine1\n$validLine2';
      final result = parser.parse(ocrText);

      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C');
      expect(result.dateOfBirth, '690806');
      expect(result.dateOfExpiry, '940623');
    });

    test('returns null when line2 has non-digit check digit position', () {
      // Replace doc check digit with a letter
      const badLine2 = 'L898902C<XUTO6908061F9406236ZE184226B<<<<<14';
      final result = parser.parse('$validLine1\n$badLine2');

      expect(result, isNull);
    });

    test('returns null when line1 does not start with P', () {
      const badLine1 = 'X<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$badLine1\n$validLine2');

      expect(result, isNull);
    });

    test('returns null for lines shorter than 44 characters', () {
      const shortLine = 'P<UTOERIKSSON<<ANNA';
      final result = parser.parse('$shortLine\n$validLine2');

      expect(result, isNull);
    });
  });
}
