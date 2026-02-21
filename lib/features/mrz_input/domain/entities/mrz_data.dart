import 'package:equatable/equatable.dart';

import 'viz_capture_result.dart';

/// MRZ data parsed from ICAO 9303 TD3 passport machine-readable zone.
///
/// The 3 required fields (documentNumber, dateOfBirth, dateOfExpiry) are
/// needed for BAC/PACE authentication. The optional fields are populated
/// when MRZ is parsed from camera OCR (not from manual entry).
class MrzData extends Equatable {
  /// Passport document number (up to 9 characters).
  final String documentNumber;

  /// Date of birth in YYMMDD format.
  final String dateOfBirth;

  /// Date of expiry in YYMMDD format.
  final String dateOfExpiry;

  /// VIZ capture result from camera (face image + quality metrics).
  /// Excluded from Equatable props since it contains Uint8List.
  final VizCaptureResult? vizCaptureResult;

  /// Raw MRZ line 1 after OCR correction (44 chars). Null for manual entry.
  final String? mrzLine1;

  /// Raw MRZ line 2 after OCR correction (44 chars). Null for manual entry.
  final String? mrzLine2;

  /// Document type from Line 1 positions 0-1 (e.g. "P", "PA").
  final String? documentType;

  /// Issuing state from Line 1 positions 2-4 (e.g. "KOR", "USA").
  final String? issuingState;

  /// Surname from Line 1 name field.
  final String? surname;

  /// Given names from Line 1 name field.
  final String? givenNames;

  /// Nationality from Line 2 positions 10-12 (e.g. "KOR").
  final String? nationality;

  /// Sex from Line 2 position 20 ("M", "F", or "<").
  final String? sex;

  const MrzData({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    this.vizCaptureResult,
    this.mrzLine1,
    this.mrzLine2,
    this.documentType,
    this.issuingState,
    this.surname,
    this.givenNames,
    this.nationality,
    this.sex,
  });

  /// Creates a copy with an optional VIZ capture result.
  MrzData withVizCapture(VizCaptureResult vizCapture) {
    return MrzData(
      documentNumber: documentNumber,
      dateOfBirth: dateOfBirth,
      dateOfExpiry: dateOfExpiry,
      vizCaptureResult: vizCapture,
      mrzLine1: mrzLine1,
      mrzLine2: mrzLine2,
      documentType: documentType,
      issuingState: issuingState,
      surname: surname,
      givenNames: givenNames,
      nationality: nationality,
      sex: sex,
    );
  }

  @override
  List<Object?> get props => [
        documentNumber,
        dateOfBirth,
        dateOfExpiry,
        mrzLine1,
        mrzLine2,
        documentType,
        issuingState,
        surname,
        givenNames,
        nationality,
        sex,
      ];
}
