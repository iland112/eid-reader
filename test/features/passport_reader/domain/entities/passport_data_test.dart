import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

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
  });
}
