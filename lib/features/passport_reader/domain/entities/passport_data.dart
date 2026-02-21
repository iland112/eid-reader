import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'face_comparison_result.dart';
import 'image_quality_metrics.dart';
import 'mrz_field_comparison.dart';
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

  /// VIZ-chip face comparison result.
  final FaceComparisonResult? faceComparisonResult;

  /// Whether MRZ OCR fields match chip DG1 fields.
  final bool? vizMrzFieldsMatch;

  /// Image quality metrics for the VIZ face capture.
  final ImageQualityMetrics? vizImageQuality;

  /// VIZ face image bytes captured from camera (for side-by-side display).
  final Uint8List? vizFaceBytes;

  /// Per-field MRZ OCR vs chip comparison results.
  final MrzFieldComparisonResult? vizMrzFieldComparison;

  /// NFC step timings in ms (debug diagnostics, excluded from equality).
  final Map<String, int> debugTimings;

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
    this.faceComparisonResult,
    this.vizMrzFieldsMatch,
    this.vizImageQuality,
    this.vizFaceBytes,
    this.vizMrzFieldComparison,
    this.debugTimings = const {},
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
    FaceComparisonResult? faceComparisonResult,
    bool? vizMrzFieldsMatch,
    ImageQualityMetrics? vizImageQuality,
    Uint8List? vizFaceBytes,
    MrzFieldComparisonResult? vizMrzFieldComparison,
    Map<String, int>? debugTimings,
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
      faceComparisonResult: faceComparisonResult ?? this.faceComparisonResult,
      vizMrzFieldsMatch: vizMrzFieldsMatch ?? this.vizMrzFieldsMatch,
      vizImageQuality: vizImageQuality ?? this.vizImageQuality,
      vizFaceBytes: vizFaceBytes ?? this.vizFaceBytes,
      vizMrzFieldComparison:
          vizMrzFieldComparison ?? this.vizMrzFieldComparison,
      debugTimings: debugTimings ?? this.debugTimings,
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
        faceComparisonResult,
        vizMrzFieldsMatch,
        vizImageQuality,
        vizMrzFieldComparison,
      ];
}
