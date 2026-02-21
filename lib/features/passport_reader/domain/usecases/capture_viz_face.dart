import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../../../core/services/face_detection_service.dart';
import '../../../../core/services/image_quality_analyzer.dart';
import '../../../mrz_input/domain/entities/viz_capture_result.dart';

/// Captures and processes a face from the passport VIZ (Visual Inspection Zone).
///
/// Pipeline:
/// 1. Detect faces in full-page image using ML Kit
/// 2. Select the largest face (passport photo is dominant)
/// 3. Crop face region from full-page image
/// 4. Analyze image quality for hologram/glare detection
/// 5. Return VizCaptureResult with face bytes + quality metrics
class CaptureVizFace {
  final FaceDetectionService _faceDetection;
  final ImageQualityAnalyzer _qualityAnalyzer;

  CaptureVizFace({
    required FaceDetectionService faceDetection,
    required ImageQualityAnalyzer qualityAnalyzer,
  })  : _faceDetection = faceDetection,
        _qualityAnalyzer = qualityAnalyzer;

  /// Captures VIZ face from a high-resolution still image.
  ///
  /// [imageBytes] - JPEG bytes from camera takePicture().
  /// [inputImage] - InputImage for ML Kit face detection.
  ///
  /// Returns null if no face is detected.
  Future<VizCaptureResult?> execute({
    required Uint8List imageBytes,
    required InputImage inputImage,
  }) async {
    // 1. Detect faces
    var faceRects = await _faceDetection.detectFaces(inputImage);

    // 2. Retry with contrast-enhanced image if no faces found
    File? enhancedFile;
    if (faceRects.isEmpty) {
      enhancedFile = await _createEnhancedImage(imageBytes);
      if (enhancedFile != null) {
        final enhancedInput = InputImage.fromFilePath(enhancedFile.path);
        faceRects = await _faceDetection.detectFaces(enhancedInput);
      }
    }

    try {
      if (faceRects.isEmpty) return null;

      // 3. Select the largest face (passport photo is typically the largest)
      final largestFace = _selectLargestFace(faceRects);

      // 4. Decode full image for cropping (always from original)
      final fullImage = img.decodeImage(imageBytes);
      if (fullImage == null) return null;

      // 5. Crop face region with padding
      final croppedBytes = _cropFace(fullImage, largestFace);
      if (croppedBytes == null) return null;

      // 6. Analyze quality of the cropped face
      final qualityMetrics = _qualityAnalyzer.analyze(croppedBytes);

      return VizCaptureResult(
        vizFaceImageBytes: croppedBytes,
        faceBoundingBox: largestFace,
        qualityMetrics: qualityMetrics,
      );
    } finally {
      // Clean up enhanced image temp file
      if (enhancedFile != null) {
        try {
          await enhancedFile.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }
  }

  /// Creates a contrast-enhanced version of the image for retry detection.
  ///
  /// Applies 1.5x linear contrast stretch to improve detection of
  /// low-contrast passport photos. Returns null on any failure.
  Future<File?> _createEnhancedImage(Uint8List imageBytes) async {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;

      // Apply 1.5x linear contrast stretch around midpoint (128)
      for (int y = 0; y < decoded.height; y++) {
        for (int x = 0; x < decoded.width; x++) {
          final pixel = decoded.getPixel(x, y);
          final r =
              (((pixel.r.toInt() - 128) * 1.5) + 128).round().clamp(0, 255);
          final g =
              (((pixel.g.toInt() - 128) * 1.5) + 128).round().clamp(0, 255);
          final b =
              (((pixel.b.toInt() - 128) * 1.5) + 128).round().clamp(0, 255);
          decoded.setPixelRgb(x, y, r, g, b);
        }
      }

      final jpegBytes = img.encodeJpg(decoded, quality: 90);
      final tempDir = Directory.systemTemp;
      final file = File(
        '${tempDir.path}/viz_enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(jpegBytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  Rect _selectLargestFace(List<Rect> faces) {
    return faces.reduce((a, b) {
      final areaA = a.width * a.height;
      final areaB = b.width * b.height;
      return areaA >= areaB ? a : b;
    });
  }

  /// Crops the face region with 20% padding and encodes as JPEG.
  Uint8List? _cropFace(img.Image fullImage, Rect faceRect) {
    // Add 20% padding around the face
    final padX = faceRect.width * 0.2;
    final padY = faceRect.height * 0.2;

    final x = (faceRect.left - padX).round().clamp(0, fullImage.width - 1);
    final y = (faceRect.top - padY).round().clamp(0, fullImage.height - 1);
    final right =
        (faceRect.right + padX).round().clamp(0, fullImage.width);
    final bottom =
        (faceRect.bottom + padY).round().clamp(0, fullImage.height);

    final cropWidth = right - x;
    final cropHeight = bottom - y;

    if (cropWidth <= 0 || cropHeight <= 0) return null;

    final cropped = img.copyCrop(
      fullImage,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  }
}
