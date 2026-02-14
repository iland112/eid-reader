import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Parsed passport data from NFC reading.
class PassportData extends Equatable {
  final String surname;
  final String givenNames;
  final String documentNumber;
  final String nationality;
  final String dateOfBirth;
  final String sex;
  final String dateOfExpiry;
  final String issuingState;
  final String documentType;
  final Uint8List? faceImageBytes;
  final bool passiveAuthValid;
  final bool? activeAuthValid;
  final String authProtocol;

  const PassportData({
    required this.surname,
    required this.givenNames,
    required this.documentNumber,
    required this.nationality,
    required this.dateOfBirth,
    required this.sex,
    required this.dateOfExpiry,
    required this.issuingState,
    required this.documentType,
    this.faceImageBytes,
    this.passiveAuthValid = false,
    this.activeAuthValid,
    this.authProtocol = 'BAC',
  });

  String get fullName => '$givenNames $surname';

  @override
  List<Object?> get props => [
        surname,
        givenNames,
        documentNumber,
        nationality,
        dateOfBirth,
        sex,
        dateOfExpiry,
        issuingState,
        documentType,
        passiveAuthValid,
        activeAuthValid,
        authProtocol,
      ];
}
