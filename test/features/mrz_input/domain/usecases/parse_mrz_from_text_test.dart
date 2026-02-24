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

  group('ParseMrzFromText Line 1 fields', () {
    const validLine1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
    const validLine2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';

    test('extracts surname from Line 1', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.surname, 'ERIKSSON');
    });

    test('extracts given names from Line 1', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.givenNames, 'ANNA MARIA');
    });

    test('extracts document type from Line 1', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.documentType, 'P');
    });

    test('extracts issuing state from Line 1', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.issuingState, 'UTO');
    });

    test('extracts nationality from Line 2', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.nationality, 'UTO');
    });

    test('extracts sex from Line 2', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.sex, 'F');
    });

    test('stores raw MRZ lines', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.mrzLine1, isNotNull);
      expect(result.mrzLine1!.length, 44);
      expect(result.mrzLine2, isNotNull);
      expect(result.mrzLine2!.length, 44);
    });

    test('MRZ Line 1 starts with P', () {
      final result = parser.parse('$validLine1\n$validLine2');
      expect(result!.mrzLine1!.startsWith('P'), isTrue);
    });

    test('handles single given name', () {
      const line1 = 'P<UTODOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.surname, 'DOE');
      expect(result.givenNames, 'JOHN');
    });

    test('handles surname only (no given names)', () {
      const line1 = 'P<UTODOE<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.surname, 'DOE');
      expect(result.givenNames, '');
    });

    test('handles multi-part surname with filler separators', () {
      const line1 = 'P<UTOVAN<DER<BERG<<ANNA<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.surname, 'VAN DER BERG');
      expect(result.givenNames, 'ANNA');
    });

    test('handles male sex', () {
      // Change sex from F to M in Line 2 position 20
      const line2Male = 'L898902C<3UTO6908061M9406236ZE184226B<<<<<14';
      final result = parser.parse('$validLine1\n$line2Male');
      expect(result, isNotNull);
      expect(result!.sex, 'M');
    });

    test('handles empty sex (filler)', () {
      // Filler in sex position
      const line2NoSex = 'L898902C<3UTO6908061<9406236ZE184226B<<<<<14';
      final result = parser.parse('$validLine1\n$line2NoSex');
      expect(result, isNotNull);
      expect(result!.sex, '');
    });
  });

  group('ParseMrzFromText ICAO 9303 document subtypes', () {
    const validLine2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';

    test('parses PM subtype (Korean passport)', () {
      const line1 = 'PMKORJUNG<<KYUNG<BAE<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.documentType, 'PM');
      expect(result.issuingState, 'KOR');
      expect(result.surname, 'JUNG');
      expect(result.givenNames, 'KYUNG BAE');
    });

    test('parses PD subtype (diplomatic passport)', () {
      const line1 = 'PDGBRDOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.documentType, 'PD');
      expect(result.issuingState, 'GBR');
      expect(result.surname, 'DOE');
      expect(result.givenNames, 'JOHN');
    });

    test('parses PO subtype (official passport)', () {
      const line1 = 'PODEUSCHMIDT<<ANNA<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.documentType, 'PO');
      expect(result.issuingState, 'DEU');
    });

    test('parses PS subtype (service passport)', () {
      const line1 = 'PSFRADUPONT<<MARIE<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.documentType, 'PS');
      expect(result.issuingState, 'FRA');
    });

    test('parses P< subtype (regular passport) with type P', () {
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.documentType, 'P');
      expect(result.issuingState, 'UTO');
    });
  });

  group('ParseMrzFromText Line 1 OCR correction', () {
    const validLine2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';

    test('corrects digit 0 to O in Line 1 name field', () {
      // Replace 'O' in ERIKSSON with '0'
      const line1 = 'P<UT0ERIKS50N<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.surname, 'ERIKSSON');
      expect(result.issuingState, 'UTO');
    });

    test('corrects digit 1 to I in Line 1', () {
      // Replace 'I' in MARIA with '1'
      const line1 = 'P<UTOER1KSSON<<ANNA<MAR1A<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.surname, 'ERIKSSON');
      expect(result.givenNames, 'ANNA MARIA');
    });

    test('corrects digit 8 to B in Line 1 issuing state', () {
      // Replace 'B' with '8' in issuing state — but UTO has no B.
      // Use a line with 'B' in state: e.g. GBR → G8R should correct to GBR
      const line1 = 'P<G8RDOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final result = parser.parse('$line1\n$validLine2');
      expect(result, isNotNull);
      expect(result!.issuingState, 'GBR');
    });
  });
}
