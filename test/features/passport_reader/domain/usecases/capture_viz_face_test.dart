import 'dart:typed_data';
import 'dart:ui';

import 'package:eid_reader/core/services/face_detection_service.dart';
import 'package:eid_reader/core/services/image_quality_analyzer.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/image_quality_metrics.dart';
import 'package:eid_reader/features/passport_reader/domain/usecases/capture_viz_face.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Mock face detection service for testing.
class MockFaceDetectionService implements FaceDetectionService {
  List<Rect> facesToReturn = [];
  int detectCallCount = 0;

  /// Per-call results for testing retry logic.
  /// When set, overrides [facesToReturn] based on call index.
  List<List<Rect>>? facesSequence;

  @override
  Future<List<Rect>> detectFaces(InputImage image) async {
    final index = detectCallCount++;
    if (facesSequence != null && index < facesSequence!.length) {
      return facesSequence![index];
    }
    return facesToReturn;
  }

  @override
  void close() {}
}

/// Mock quality analyzer that returns fixed metrics.
class MockImageQualityAnalyzer implements ImageQualityAnalyzer {
  ImageQualityMetrics metricsToReturn = const ImageQualityMetrics(
    blurScore: 100,
    glareRatio: 0.02,
    saturationStdDev: 0.1,
    contrastRatio: 0.5,
    overallScore: 0.8,
  );

  @override
  ImageQualityMetrics analyze(Uint8List imageBytes) {
    return metricsToReturn;
  }
}

/// Creates a test JPEG image with given dimensions.
Uint8List _createTestJpeg({int width = 200, int height = 300}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(x, y, 128, 128, 128);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  late MockFaceDetectionService mockFaceDetection;
  late MockImageQualityAnalyzer mockQualityAnalyzer;
  late CaptureVizFace captureVizFace;

  setUp(() {
    mockFaceDetection = MockFaceDetectionService();
    mockQualityAnalyzer = MockImageQualityAnalyzer();
    captureVizFace = CaptureVizFace(
      faceDetection: mockFaceDetection,
      qualityAnalyzer: mockQualityAnalyzer,
    );
  });

  group('CaptureVizFace', () {
    test('returns null when no faces detected', () async {
      mockFaceDetection.facesToReturn = [];
      final imageBytes = _createTestJpeg();
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNull);
    });

    test('returns VizCaptureResult when face detected', () async {
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(50, 60, 80, 100),
      ];
      final imageBytes = _createTestJpeg();
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNotNull);
      expect(result!.vizFaceImageBytes, isNotEmpty);
      expect(result.faceBoundingBox, const Rect.fromLTWH(50, 60, 80, 100));
    });

    test('selects largest face when multiple detected', () async {
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(10, 10, 20, 20), // small face (area 400)
        const Rect.fromLTWH(50, 50, 80, 100), // large face (area 8000)
        const Rect.fromLTWH(30, 30, 30, 30), // medium face (area 900)
      ];
      final imageBytes = _createTestJpeg();
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNotNull);
      expect(result!.faceBoundingBox, const Rect.fromLTWH(50, 50, 80, 100));
    });

    test('includes quality metrics in result', () async {
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(50, 60, 80, 100),
      ];
      mockQualityAnalyzer.metricsToReturn = const ImageQualityMetrics(
        blurScore: 150,
        glareRatio: 0.01,
        saturationStdDev: 0.08,
        contrastRatio: 0.6,
        overallScore: 0.9,
        issues: [],
      );
      final imageBytes = _createTestJpeg();
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNotNull);
      expect(result!.qualityMetrics.blurScore, 150);
      expect(result.qualityMetrics.overallScore, 0.9);
    });

    test('handles face at image edge with padding clamp', () async {
      // Face near the edge: padding would go out of bounds
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(0, 0, 50, 60),
      ];
      final imageBytes = _createTestJpeg(width: 100, height: 100);
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(100, 100),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 100,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNotNull);
      expect(result!.vizFaceImageBytes, isNotEmpty);
    });

    test('handles face near bottom-right edge', () async {
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(150, 240, 50, 60),
      ];
      final imageBytes = _createTestJpeg(width: 200, height: 300);
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNotNull);
    });

    test('retries with contrast enhancement when first attempt fails',
        () async {
      // First call: no faces; second call (enhanced): face found
      mockFaceDetection.facesSequence = [
        [], // first attempt
        [const Rect.fromLTWH(50, 60, 80, 100)], // retry with enhancement
      ];
      final imageBytes = _createTestJpeg();
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNotNull);
      expect(result!.vizFaceImageBytes, isNotEmpty);
      expect(mockFaceDetection.detectCallCount, 2);
    });

    test('does not retry when first attempt succeeds', () async {
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(50, 60, 80, 100),
      ];
      final imageBytes = _createTestJpeg();
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNotNull);
      expect(mockFaceDetection.detectCallCount, 1);
    });

    test('returns null when both attempts fail', () async {
      // Both calls return empty
      mockFaceDetection.facesSequence = [
        [], // first attempt
        [], // retry with enhancement
      ];
      final imageBytes = _createTestJpeg();
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(200, 300),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );

      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      expect(result, isNull);
      expect(mockFaceDetection.detectCallCount, 2);
    });
  });
}
