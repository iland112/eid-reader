import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/passport_reader/domain/entities/pa_verification_result.dart';

void main() {
  group('PaVerificationResult', () {
    test('isValid returns true for VALID status', () {
      const result = PaVerificationResult(status: 'VALID');
      expect(result.isValid, true);
    });

    test('isValid returns false for INVALID status', () {
      const result = PaVerificationResult(status: 'INVALID');
      expect(result.isValid, false);
    });

    test('isValid returns false for ERROR status', () {
      const result = PaVerificationResult(status: 'ERROR');
      expect(result.isValid, false);
    });

    test('fromJson parses VALID response correctly', () {
      final json = <String, dynamic>{
        'success': true,
        'data': {
          'status': 'VALID',
          'verificationId': 'test-uuid-123',
          'processingDurationMs': 245,
          'certificateChainValidation': {
            'valid': true,
            'dscSubject': '/C=KR/CN=DSC 01',
            'cscaSubject': '/C=KR/CN=CSCA KR',
            'crlStatus': 'NOT_REVOKED',
            'dscExpired': false,
            'cscaExpired': false,
          },
          'sodSignatureValidation': {
            'valid': true,
            'hashAlgorithm': 'SHA-256',
            'signatureAlgorithm': 'SHA256withRSA',
          },
          'dataGroupValidation': {
            'totalGroups': 2,
            'validGroups': 2,
            'invalidGroups': 0,
          },
        },
      };

      final result = PaVerificationResult.fromJson(json);
      expect(result.status, 'VALID');
      expect(result.isValid, true);
      expect(result.verificationId, 'test-uuid-123');
      expect(result.processingDurationMs, 245);
      expect(result.certificateChainValid, true);
      expect(result.dscSubject, '/C=KR/CN=DSC 01');
      expect(result.cscaSubject, '/C=KR/CN=CSCA KR');
      expect(result.crlStatus, 'NOT_REVOKED');
      expect(result.dscExpired, false);
      expect(result.cscaExpired, false);
      expect(result.sodSignatureValid, true);
      expect(result.hashAlgorithm, 'SHA-256');
      expect(result.signatureAlgorithm, 'SHA256withRSA');
      expect(result.totalGroups, 2);
      expect(result.validGroups, 2);
      expect(result.invalidGroups, 0);
      expect(result.errorMessage, isNull);
    });

    test('fromJson parses INVALID response correctly', () {
      final json = <String, dynamic>{
        'success': true,
        'data': {
          'status': 'INVALID',
          'verificationId': 'test-uuid-456',
          'processingDurationMs': 156,
          'certificateChainValidation': {
            'valid': false,
          },
          'sodSignatureValidation': {
            'valid': true,
            'hashAlgorithm': 'SHA-256',
            'signatureAlgorithm': 'SHA256withRSA',
          },
          'dataGroupValidation': {
            'totalGroups': 2,
            'validGroups': 2,
            'invalidGroups': 0,
          },
        },
      };

      final result = PaVerificationResult.fromJson(json);
      expect(result.status, 'INVALID');
      expect(result.isValid, false);
      expect(result.certificateChainValid, false);
    });

    test('fromJson handles error response without data', () {
      final json = <String, dynamic>{
        'success': false,
        'error': 'SOD parsing failed',
      };

      final result = PaVerificationResult.fromJson(json);
      expect(result.status, 'ERROR');
      expect(result.isValid, false);
      expect(result.errorMessage, 'SOD parsing failed');
    });

    test('fromJson handles missing nested objects', () {
      final json = <String, dynamic>{
        'success': true,
        'data': {
          'status': 'VALID',
        },
      };

      final result = PaVerificationResult.fromJson(json);
      expect(result.status, 'VALID');
      expect(result.certificateChainValid, isNull);
      expect(result.sodSignatureValid, isNull);
      expect(result.totalGroups, isNull);
    });

    test('error factory creates ERROR result', () {
      final result = PaVerificationResult.error('Network timeout');
      expect(result.status, 'ERROR');
      expect(result.isValid, false);
      expect(result.errorMessage, 'Network timeout');
    });

    test('two instances with same values are equal', () {
      const a = PaVerificationResult(status: 'VALID', verificationId: 'abc');
      const b = PaVerificationResult(status: 'VALID', verificationId: 'abc');
      expect(a, equals(b));
    });

    test('instances with different values are not equal', () {
      const a = PaVerificationResult(status: 'VALID');
      const b = PaVerificationResult(status: 'INVALID');
      expect(a, isNot(equals(b)));
    });

    test('props includes all fields', () {
      const result = PaVerificationResult(
        status: 'VALID',
        verificationId: 'id',
        processingDurationMs: 100,
        certificateChainValid: true,
        dscSubject: 'dsc',
        cscaSubject: 'csca',
        crlStatus: 'NOT_REVOKED',
        dscExpired: false,
        cscaExpired: false,
        sodSignatureValid: true,
        hashAlgorithm: 'SHA-256',
        signatureAlgorithm: 'RSA',
        totalGroups: 2,
        validGroups: 2,
        invalidGroups: 0,
        errorMessage: null,
      );
      expect(result.props.length, 16);
    });
  });
}
