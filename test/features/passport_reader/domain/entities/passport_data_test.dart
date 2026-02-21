import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/passport_reader/domain/entities/pa_verification_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/passport_data.dart';

PassportData _createPassportData({
  String surname = 'DOE',
  String givenNames = 'JOHN',
  String documentNumber = 'L898902C',
  String nationality = 'USA',
  String dateOfBirth = '690806',
  String sex = 'M',
  String dateOfExpiry = '940623',
  String issuingState = 'USA',
  String documentType = 'P',
  Uint8List? faceImageBytes,
  bool passiveAuthValid = false,
  bool? activeAuthValid,
  String authProtocol = 'BAC',
}) {
  return PassportData(
    surname: surname,
    givenNames: givenNames,
    documentNumber: documentNumber,
    nationality: nationality,
    dateOfBirth: dateOfBirth,
    sex: sex,
    dateOfExpiry: dateOfExpiry,
    issuingState: issuingState,
    documentType: documentType,
    faceImageBytes: faceImageBytes,
    passiveAuthValid: passiveAuthValid,
    activeAuthValid: activeAuthValid,
    authProtocol: authProtocol,
  );
}

void main() {
  group('PassportData', () {
    test('fullName concatenates givenNames and surname', () {
      final data = _createPassportData(
        givenNames: 'JOHN',
        surname: 'DOE',
      );
      expect(data.fullName, 'JOHN DOE');
    });

    test('defaults passiveAuthValid to false', () {
      final data = _createPassportData();
      expect(data.passiveAuthValid, false);
    });

    test('defaults activeAuthValid to null', () {
      final data = _createPassportData();
      expect(data.activeAuthValid, isNull);
    });

    test('defaults authProtocol to BAC', () {
      final data = _createPassportData();
      expect(data.authProtocol, 'BAC');
    });

    test('defaults faceImageBytes to null', () {
      final data = _createPassportData();
      expect(data.faceImageBytes, isNull);
    });

    test('two instances with same values are equal', () {
      final a = _createPassportData();
      final b = _createPassportData();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances with different field values are not equal', () {
      final a = _createPassportData(surname: 'DOE');
      final b = _createPassportData(surname: 'SMITH');
      expect(a, isNot(equals(b)));
    });

    test('faceImageBytes is excluded from equality', () {
      final a = _createPassportData(
        faceImageBytes: Uint8List.fromList([1, 2, 3]),
      );
      final b = _createPassportData(
        faceImageBytes: Uint8List.fromList([4, 5, 6]),
      );
      expect(a, equals(b));
    });

    test('equality considers authProtocol', () {
      final a = _createPassportData(authProtocol: 'BAC');
      final b = _createPassportData(authProtocol: 'PACE');
      expect(a, isNot(equals(b)));
    });

    test('defaults paVerificationResult to null', () {
      final data = _createPassportData();
      expect(data.paVerificationResult, isNull);
    });

    test('equality considers paVerificationResult', () {
      final a = _createPassportData();
      final b = a.copyWith(
        paVerificationResult:
            const PaVerificationResult(status: 'VALID'),
      );
      expect(a, isNot(equals(b)));
    });

    test('copyWith preserves unchanged fields', () {
      final original = _createPassportData(
        surname: 'DOE',
        givenNames: 'JOHN',
        authProtocol: 'PACE',
      );
      final copy = original.copyWith(passiveAuthValid: true);
      expect(copy.surname, 'DOE');
      expect(copy.givenNames, 'JOHN');
      expect(copy.authProtocol, 'PACE');
      expect(copy.passiveAuthValid, true);
    });

    test('copyWith updates passiveAuthValid and paVerificationResult', () {
      final original = _createPassportData();
      const paResult = PaVerificationResult(status: 'VALID');
      final copy = original.copyWith(
        passiveAuthValid: true,
        paVerificationResult: paResult,
      );
      expect(copy.passiveAuthValid, true);
      expect(copy.paVerificationResult, paResult);
    });

    test('copyWith updates all fields', () {
      final original = _createPassportData();
      final copy = original.copyWith(
        surname: 'SMITH',
        givenNames: 'JANE',
        documentNumber: 'X1234567',
        nationality: 'GBR',
        dateOfBirth: '850315',
        sex: 'F',
        dateOfExpiry: '350315',
        issuingState: 'GBR',
        documentType: 'P',
        passiveAuthValid: true,
        activeAuthValid: true,
        authProtocol: 'PACE',
      );
      expect(copy.surname, 'SMITH');
      expect(copy.givenNames, 'JANE');
      expect(copy.documentNumber, 'X1234567');
      expect(copy.nationality, 'GBR');
      expect(copy.dateOfBirth, '850315');
      expect(copy.sex, 'F');
      expect(copy.dateOfExpiry, '350315');
      expect(copy.issuingState, 'GBR');
      expect(copy.documentType, 'P');
      expect(copy.passiveAuthValid, true);
      expect(copy.activeAuthValid, true);
      expect(copy.authProtocol, 'PACE');
    });
  });
}
