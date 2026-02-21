import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'pa_verification_result.dart';

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
  final PaVerificationResult? paVerificationResult;

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
    this.paVerificationResult,
  });

  String get fullName => '$givenNames $surname';

  PassportData copyWith({
    String? surname,
    String? givenNames,
    String? documentNumber,
    String? nationality,
    String? dateOfBirth,
    String? sex,
    String? dateOfExpiry,
    String? issuingState,
    String? documentType,
    Uint8List? faceImageBytes,
    bool? passiveAuthValid,
    bool? activeAuthValid,
    String? authProtocol,
    PaVerificationResult? paVerificationResult,
  }) {
    return PassportData(
      surname: surname ?? this.surname,
      givenNames: givenNames ?? this.givenNames,
      documentNumber: documentNumber ?? this.documentNumber,
      nationality: nationality ?? this.nationality,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      sex: sex ?? this.sex,
      dateOfExpiry: dateOfExpiry ?? this.dateOfExpiry,
      issuingState: issuingState ?? this.issuingState,
      documentType: documentType ?? this.documentType,
      faceImageBytes: faceImageBytes ?? this.faceImageBytes,
      passiveAuthValid: passiveAuthValid ?? this.passiveAuthValid,
      activeAuthValid: activeAuthValid ?? this.activeAuthValid,
      authProtocol: authProtocol ?? this.authProtocol,
      paVerificationResult: paVerificationResult ?? this.paVerificationResult,
    );
  }

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
        paVerificationResult,
      ];
}
