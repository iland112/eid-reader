import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/mrz_input/domain/entities/viz_capture_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/image_quality_metrics.dart';

void main() {
  group('MrzData.toPassportData', () {
    test('maps required fields correctly', () {
      const mrz = MrzData(
        documentNumber: 'M12345678',
        dateOfBirth: '900115',
        dateOfExpiry: '300115',
        surname: 'DOE',
        givenNames: 'JOHN',
        nationality: 'USA',
        issuingState: 'USA',
        documentType: 'P',
        sex: 'M',
      );

      final passport = mrz.toPassportData();

      expect(passport.documentNumber, 'M12345678');
      expect(passport.dateOfBirth, '900115');
      expect(passport.dateOfExpiry, '300115');
      expect(passport.surname, 'DOE');
      expect(passport.givenNames, 'JOHN');
      expect(passport.nationality, 'USA');
      expect(passport.issuingState, 'USA');
      expect(passport.documentType, 'P');
      expect(passport.sex, 'M');
    });

    test('sets authProtocol to OCR', () {
      const mrz = MrzData(
        documentNumber: 'M12345678',
        dateOfBirth: '900115',
        dateOfExpiry: '300115',
      );

      final passport = mrz.toPassportData();
      expect(passport.authProtocol, 'OCR');
      expect(passport.isOcrOnly, isTrue);
    });

    test('maps null optional fields to empty strings', () {
      const mrz = MrzData(
        documentNumber: 'M12345678',
        dateOfBirth: '900115',
        dateOfExpiry: '300115',
      );

      final passport = mrz.toPassportData();
      expect(passport.surname, '');
      expect(passport.givenNames, '');
      expect(passport.nationality, '');
      expect(passport.issuingState, '');
      expect(passport.sex, '');
      expect(passport.documentType, 'P');
    });

    test('maps vizCaptureResult face bytes and quality', () {
      final faceBytes = Uint8List.fromList([1, 2, 3]);
      const quality = ImageQualityMetrics(
        blurScore: 120.0,
        glareRatio: 0.02,
        saturationStdDev: 0.1,
        contrastRatio: 0.5,
        overallScore: 0.8,
      );
      final mrz = MrzData(
        documentNumber: 'M12345678',
        dateOfBirth: '900115',
        dateOfExpiry: '300115',
        vizCaptureResult: VizCaptureResult(
          vizFaceImageBytes: faceBytes,
          faceBoundingBox: const Rect.fromLTWH(10, 20, 100, 120),
          qualityMetrics: quality,
        ),
      );

      final passport = mrz.toPassportData();
      expect(passport.vizFaceBytes, faceBytes);
      expect(passport.vizImageQuality, quality);
    });

    test('leaves chip-only fields as defaults', () {
      const mrz = MrzData(
        documentNumber: 'M12345678',
        dateOfBirth: '900115',
        dateOfExpiry: '300115',
      );

      final passport = mrz.toPassportData();
      expect(passport.passiveAuthValid, isFalse);
      expect(passport.activeAuthValid, isNull);
      expect(passport.faceImageBytes, isNull);
      expect(passport.paVerificationResult, isNull);
      expect(passport.debugTimings, isEmpty);
    });
  });
}
