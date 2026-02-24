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

  @override
  Future<List<Rect>> detectFaces(InputImage image) async {
    detectCallCount++;
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

  @override
  ImageQualityMetrics analyzeFromPixels(
      ByteData rgbaPixels, int width, int height) {
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

    test('calls face detection exactly once', () async {
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

    test('returns null immediately when no faces detected', () async {
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
      expect(mockFaceDetection.detectCallCount, 1);
    });
  });

  group('CaptureVizFace with previewFaceRect', () {
    test('skips ML Kit when previewFaceRect is provided', () async {
      // ML Kit should NOT be called when preview face rect is given
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(10, 10, 20, 20),
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
        previewFaceRect: const Rect.fromLTWH(50, 60, 80, 100),
        previewSize: const Size(200, 300),
      );

      expect(result, isNotNull);
      expect(mockFaceDetection.detectCallCount, 0);
    });

    test('scales preview rect to full image coordinates', () async {
      // Preview is 100x150, full image is 200x300 → scale 2x
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
        previewFaceRect: const Rect.fromLTWH(25, 30, 40, 50),
        previewSize: const Size(100, 150),
      );

      expect(result, isNotNull);
      expect(mockFaceDetection.detectCallCount, 0);
    });

    test('falls back to ML Kit when scaled rect is out of bounds', () async {
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(50, 60, 80, 100),
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

      // Preview rect that will scale way out of bounds
      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
        previewFaceRect: const Rect.fromLTWH(500, 600, 80, 100),
        previewSize: const Size(100, 100),
      );

      expect(result, isNotNull);
      expect(mockFaceDetection.detectCallCount, 1); // Fallback to ML Kit
    });

    test('falls back to ML Kit when previewSize is null', () async {
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
        previewFaceRect: const Rect.fromLTWH(50, 60, 80, 100),
        // previewSize is null → should use ML Kit
      );

      expect(result, isNotNull);
      expect(mockFaceDetection.detectCallCount, 1);
    });

    test('prefers left-side face over similar-sized right-side face (ghost image)', () async {
      // Simulate polycarbonate passport with ghost image:
      // Main photo (left, 40x50) vs ghost image (right, slightly larger 42x52)
      // In a 200-wide image: main center X = 30 (15%), ghost center X = 160 (80%)
      // Without position bias: ghost wins (2184 > 2000)
      // With position bias: main = 2000*1.5 = 3000, ghost = 2184*1.0 → main wins
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(10, 100, 40, 50),   // main photo (left)
        const Rect.fromLTWH(139, 100, 42, 52),  // ghost image (right, slightly larger)
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
      // Should select the left face (main photo), not the ghost
      expect(result!.faceBoundingBox.left, 10);
    });

    test('selects right-side face when it is much larger (no ghost)', () async {
      // If the right-side face is >1.5x larger, it should still win
      // (e.g., the passport is flipped or it's genuinely the main face)
      mockFaceDetection.facesToReturn = [
        const Rect.fromLTWH(10, 100, 20, 25),   // small left face (area 500)
        const Rect.fromLTWH(120, 100, 60, 80),  // large right face (area 4800)
      ];
      // score: left = 500*1.5 = 750, right = 4800*1.0 = 4800 → right wins
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
      // Right face is >1.5x larger, so it wins despite position
      expect(result!.faceBoundingBox.left, 120);
    });

    test('returns null when fallback ML Kit finds no faces', () async {
      mockFaceDetection.facesToReturn = []; // No faces
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

      // Out of bounds → fallback → no faces
      final result = await captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
        previewFaceRect: const Rect.fromLTWH(500, 600, 80, 100),
        previewSize: const Size(100, 100),
      );

      expect(result, isNull);
    });
  });
}
