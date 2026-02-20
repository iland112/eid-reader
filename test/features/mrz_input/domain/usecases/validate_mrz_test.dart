import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/mrz_input/domain/usecases/validate_mrz.dart';

void main() {
  late ValidateMrz validateMrz;

  setUp(() {
    validateMrz = ValidateMrz();
  });

  group('validateDocumentNumber', () {
    test('returns null for valid document number', () {
      expect(validateMrz.validateDocumentNumber('L898902C'), isNull);
    });

    test('accepts single character', () {
      expect(validateMrz.validateDocumentNumber('A'), isNull);
    });

    test('accepts 9 character max', () {
      expect(validateMrz.validateDocumentNumber('L12345678'), isNull);
    });

    test('returns error for empty string', () {
      expect(validateMrz.validateDocumentNumber(''), isNotNull);
    });

    test('returns error for more than 9 characters', () {
      expect(validateMrz.validateDocumentNumber('1234567890'), isNotNull);
    });

    test('returns error for special characters', () {
      expect(validateMrz.validateDocumentNumber('L898-02C'), isNotNull);
    });

    test('accepts lowercase (uppercased internally)', () {
      expect(validateMrz.validateDocumentNumber('l898902c'), isNull);
    });
  });

  group('validateDate', () {
    test('returns null for valid date', () {
      expect(validateMrz.validateDate('690806'), isNull);
    });

    test('returns error for empty string', () {
      expect(validateMrz.validateDate(''), isNotNull);
    });

    test('returns error for too short', () {
      expect(validateMrz.validateDate('12345'), isNotNull);
    });

    test('returns error for too long', () {
      expect(validateMrz.validateDate('1234567'), isNotNull);
    });

    test('returns error for non-digit characters', () {
      expect(validateMrz.validateDate('69AB06'), isNotNull);
    });

    test('returns error for invalid month 00', () {
      expect(validateMrz.validateDate('690006'), isNotNull);
    });

    test('returns error for invalid month 13', () {
      expect(validateMrz.validateDate('691306'), isNotNull);
    });

    test('returns error for invalid day 00', () {
      expect(validateMrz.validateDate('690800'), isNotNull);
    });

    test('returns error for invalid day 32', () {
      expect(validateMrz.validateDate('690832'), isNotNull);
    });

    test('accepts month 12 and day 31', () {
      expect(validateMrz.validateDate('691231'), isNull);
    });

    test('uses custom field name in error messages', () {
      final error = validateMrz.validateDate('', fieldName: 'Date of birth');
      expect(error, contains('Date of birth'));
    });

    test('uses default field name when not specified', () {
      final error = validateMrz.validateDate('');
      expect(error, contains('Date'));
    });
  });

  group('validate (full MrzData)', () {
    test('returns null for valid MrzData', () {
      const data = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      expect(validateMrz.validate(data), isNull);
    });

    test('returns error when document number is empty', () {
      const data = MrzData(
        documentNumber: '',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      final error = validateMrz.validate(data);
      expect(error, contains('Document number'));
    });

    test('returns error when date of birth is invalid', () {
      const data = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '001306',
        dateOfExpiry: '940623',
      );
      expect(validateMrz.validate(data), isNotNull);
    });

    test('returns error when date of expiry is invalid', () {
      const data = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '001301',
      );
      expect(validateMrz.validate(data), isNotNull);
    });
  });
}
