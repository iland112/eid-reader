import 'package:equatable/equatable.dart';

/// Result of Passive Authentication verification via PA Service API.
class PaVerificationResult extends Equatable {
  final String status;
  final String? verificationId;
  final int? processingDurationMs;

  // Certificate chain validation
  final bool? certificateChainValid;
  final String? dscSubject;
  final String? cscaSubject;
  final String? crlStatus;
  final bool? dscExpired;
  final bool? cscaExpired;

  // SOD signature validation
  final bool? sodSignatureValid;
  final String? hashAlgorithm;
  final String? signatureAlgorithm;

  // Data group validation
  final int? totalGroups;
  final int? validGroups;
  final int? invalidGroups;

  // Certificate chain extended fields (v2.1.4+)
  final bool? validAtSigningTime;
  final String? expirationStatus;
  final String? expirationMessage;
  final bool? dscNonConformant;
  final String? pkdConformanceCode;
  final String? pkdConformanceText;

  // DSC auto-registration (v2.1.1+)
  final String? dscFingerprint;

  // Error info
  final String? errorMessage;

  const PaVerificationResult({
    required this.status,
    this.verificationId,
    this.processingDurationMs,
    this.certificateChainValid,
    this.dscSubject,
    this.cscaSubject,
    this.crlStatus,
    this.dscExpired,
    this.cscaExpired,
    this.validAtSigningTime,
    this.expirationStatus,
    this.expirationMessage,
    this.dscNonConformant,
    this.pkdConformanceCode,
    this.pkdConformanceText,
    this.dscFingerprint,
    this.sodSignatureValid,
    this.hashAlgorithm,
    this.signatureAlgorithm,
    this.totalGroups,
    this.validGroups,
    this.invalidGroups,
    this.errorMessage,
  });

  bool get isValid => status == 'VALID';

  /// Creates from PA API success response JSON (`data` object).
  factory PaVerificationResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      return PaVerificationResult.error(
        json['error'] as String? ?? 'Unknown API error',
      );
    }

    final certChain =
        data['certificateChainValidation'] as Map<String, dynamic>?;
    final sodSig =
        data['sodSignatureValidation'] as Map<String, dynamic>?;
    final dgValidation =
        data['dataGroupValidation'] as Map<String, dynamic>?;
    final dscReg =
        data['dscAutoRegistration'] as Map<String, dynamic>?;

    return PaVerificationResult(
      status: data['status'] as String? ?? 'UNKNOWN',
      verificationId: data['verificationId'] as String?,
      processingDurationMs: data['processingDurationMs'] as int?,
      certificateChainValid: certChain?['valid'] as bool?,
      dscSubject: certChain?['dscSubject'] as String?,
      cscaSubject: certChain?['cscaSubject'] as String?,
      crlStatus: certChain?['crlStatus'] as String?,
      dscExpired: certChain?['dscExpired'] as bool?,
      cscaExpired: certChain?['cscaExpired'] as bool?,
      validAtSigningTime: certChain?['validAtSigningTime'] as bool?,
      expirationStatus: certChain?['expirationStatus'] as String?,
      expirationMessage: certChain?['expirationMessage'] as String?,
      dscNonConformant: certChain?['dscNonConformant'] as bool?,
      pkdConformanceCode: certChain?['pkdConformanceCode'] as String?,
      pkdConformanceText: certChain?['pkdConformanceText'] as String?,
      dscFingerprint: dscReg?['fingerprint'] as String?,
      sodSignatureValid: sodSig?['valid'] as bool?,
      hashAlgorithm: sodSig?['hashAlgorithm'] as String?,
      signatureAlgorithm: sodSig?['signatureAlgorithm'] as String?,
      totalGroups: dgValidation?['totalGroups'] as int?,
      validGroups: dgValidation?['validGroups'] as int?,
      invalidGroups: dgValidation?['invalidGroups'] as int?,
    );
  }

  /// Creates an error result for API/network failures.
  factory PaVerificationResult.error(String message) {
    return PaVerificationResult(
      status: 'ERROR',
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [
        status,
        verificationId,
        processingDurationMs,
        certificateChainValid,
        dscSubject,
        cscaSubject,
        crlStatus,
        dscExpired,
        cscaExpired,
        validAtSigningTime,
        expirationStatus,
        expirationMessage,
        dscNonConformant,
        pkdConformanceCode,
        pkdConformanceText,
        dscFingerprint,
        sodSignatureValid,
        hashAlgorithm,
        signatureAlgorithm,
        totalGroups,
        validGroups,
        invalidGroups,
        errorMessage,
      ];
}
