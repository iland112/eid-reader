import 'dart:typed_data';
import 'dart:ui';

import 'package:eid_reader/features/mrz_input/domain/entities/viz_capture_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/image_quality_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VizCaptureResult', () {
    test('stores face image bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = VizCaptureResult(
        vizFaceImageBytes: bytes,
        faceBoundingBox: const Rect.fromLTWH(10, 20, 100, 120),
        qualityMetrics: const ImageQualityMetrics(
          blurScore: 100,
          glareRatio: 0.02,
          saturationStdDev: 0.1,
          contrastRatio: 0.5,
          overallScore: 0.8,
        ),
      );
      expect(result.vizFaceImageBytes, bytes);
      expect(result.vizFaceImageBytes.length, 5);
    });

    test('stores face bounding box', () {
      final result = VizCaptureResult(
        vizFaceImageBytes: Uint8List(10),
        faceBoundingBox: const Rect.fromLTWH(50, 60, 200, 250),
        qualityMetrics: const ImageQualityMetrics(
          blurScore: 100,
          glareRatio: 0.02,
          saturationStdDev: 0.1,
          contrastRatio: 0.5,
          overallScore: 0.8,
        ),
      );
      expect(result.faceBoundingBox.left, 50);
      expect(result.faceBoundingBox.top, 60);
      expect(result.faceBoundingBox.width, 200);
      expect(result.faceBoundingBox.height, 250);
    });

    test('stores quality metrics', () {
      final result = VizCaptureResult(
        vizFaceImageBytes: Uint8List(10),
        faceBoundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        qualityMetrics: const ImageQualityMetrics(
          blurScore: 150,
          glareRatio: 0.01,
          saturationStdDev: 0.08,
          contrastRatio: 0.6,
          overallScore: 0.9,
        ),
      );
      expect(result.qualityMetrics.blurScore, 150);
      expect(result.qualityMetrics.qualityLevel, ImageQualityLevel.good);
    });

    test('quality metrics issues propagated', () {
      final result = VizCaptureResult(
        vizFaceImageBytes: Uint8List(10),
        faceBoundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        qualityMetrics: const ImageQualityMetrics(
          blurScore: 20,
          glareRatio: 0.3,
          saturationStdDev: 0.35,
          contrastRatio: 0.1,
          overallScore: 0.2,
          issues: ['Image is blurry', 'Severe glare detected'],
        ),
      );
      expect(result.qualityMetrics.issues, hasLength(2));
      expect(result.qualityMetrics.qualityLevel, ImageQualityLevel.unusable);
    });
  });
}
