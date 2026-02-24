import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:logging/logging.dart';

import '../../../../core/services/face_detection_service.dart';
import '../../../../core/services/image_quality_analyzer.dart';
import '../../../mrz_input/domain/entities/viz_capture_result.dart';

final _log = Logger('CaptureVizFace');

/// Captures and processes a face from the passport VIZ (Visual Inspection Zone).
///
/// Pipeline:
/// 1. Detect faces in full-page image using ML Kit
/// 2. Select the largest face (passport photo is dominant)
/// 3. Decode image using dart:ui native decoder (Skia/Impeller)
/// 4. Crop face region using Canvas API
/// 5. Analyze image quality for hologram/glare detection
/// 6. Return VizCaptureResult with face bytes + quality metrics
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
  /// [rotationCompensation] - Degrees to rotate raw sensor image to match
  ///   display orientation. Computed as
  ///   `(sensorOrientation - deviceOrientationDegrees + 360) % 360`.
  ///   Typical values: 90 (portrait), 0 (landscape left), 180 (landscape right).
  /// [previewFaceRect] - Optional face rect detected from a preview frame,
  ///   in preview-frame coordinates. If provided, ML Kit detection is skipped.
  /// [previewSize] - Dimensions of the preview frame for coordinate scaling.
  ///
  /// Returns null if no face is detected.
  Future<VizCaptureResult?> execute({
    required Uint8List imageBytes,
    required InputImage inputImage,
    int rotationCompensation = 90,
    Rect? previewFaceRect,
    Size? previewSize,
  }) async {
    final sw = Stopwatch()..start();

    // 1. Decode full image first (needed for both paths — scaling and crop).
    //    dart:ui native decoder (Skia/Impeller) is 5-10x faster than pure-Dart.
    //    instantiateImageCodec handles EXIF orientation automatically.
    final fullImage = await _decodeImage(imageBytes);
    _log.info(
      'Image decoded: ${fullImage.width}x${fullImage.height} '
      '(${sw.elapsedMilliseconds}ms)',
    );

    // 2. Determine face rect
    Rect largestFace;
    if (previewFaceRect != null && previewSize != null) {
      // Scale preview coordinates to full-image coordinates
      final scaleX = fullImage.width / previewSize.width;
      final scaleY = fullImage.height / previewSize.height;
      largestFace = Rect.fromLTRB(
        previewFaceRect.left * scaleX,
        previewFaceRect.top * scaleY,
        previewFaceRect.right * scaleX,
        previewFaceRect.bottom * scaleY,
      );
      _log.info(
        'Scaled preview face: '
        '${largestFace.left.toInt()},${largestFace.top.toInt()} '
        '${largestFace.width.toInt()}x${largestFace.height.toInt()} '
        '(${sw.elapsedMilliseconds}ms)',
      );

      // Bounds check — fall back to ML Kit if scaled rect is invalid
      if (largestFace.right > fullImage.width ||
          largestFace.bottom > fullImage.height ||
          largestFace.left < 0 ||
          largestFace.top < 0) {
        _log.warning('Scaled face rect out of bounds, falling back to ML Kit');
        final faceRects = await _faceDetection.detectFaces(inputImage);
        if (faceRects.isEmpty) {
          fullImage.dispose();
          return null;
        }
        largestFace = _selectMainFace(
          faceRects, imageWidth: fullImage.width.toDouble());
      }
    } else {
      // Standard path: ML Kit face detection on high-res image
      final faceRects = await _faceDetection.detectFaces(inputImage);
      _log.info(
        'Face detection: ${faceRects.length} face(s) found '
        '(${sw.elapsedMilliseconds}ms)',
      );
      if (faceRects.isEmpty) {
        fullImage.dispose();
        return null;
      }
      largestFace = _selectMainFace(
          faceRects, imageWidth: fullImage.width.toDouble());
    }

    _log.info(
      'Largest face: ${largestFace.left.toInt()},${largestFace.top.toInt()} '
      '${largestFace.width.toInt()}x${largestFace.height.toInt()}',
    );

    // 3. Handle rotation if face rect doesn't fit decoded image bounds.
    //    dart:ui handles EXIF orientation, but if face rect still doesn't fit
    //    (rare edge case), apply manual rotation compensation.
    ui.Image orientedImage;
    if (largestFace.right > fullImage.width ||
        largestFace.bottom > fullImage.height) {
      _log.info(
        'Face rect out of bounds, '
        'applying rotationCompensation=$rotationCompensation',
      );
      if (rotationCompensation != 0) {
        orientedImage = await _rotateImage(fullImage, rotationCompensation);
        fullImage.dispose();
      } else {
        orientedImage = fullImage;
      }
      _log.info(
        'Rotated image: ${orientedImage.width}x${orientedImage.height} '
        '(${sw.elapsedMilliseconds}ms)',
      );
    } else {
      orientedImage = fullImage;
    }

    // 4. Crop face region with padding using Canvas API
    final cropResult = await _cropFace(orientedImage, largestFace);
    orientedImage.dispose();
    if (cropResult == null) {
      _log.warning('Crop returned null');
      return null;
    }
    _log.info(
      'Face cropped: ${cropResult.pngBytes.length} bytes '
      '(${sw.elapsedMilliseconds}ms)',
    );

    // 5. Analyze quality from raw RGBA pixels (no second decode needed)
    final qualityMetrics = _qualityAnalyzer.analyzeFromPixels(
      cropResult.rgbaPixels,
      cropResult.width,
      cropResult.height,
    );

    _log.info(
      'VIZ face capture complete: score=${qualityMetrics.overallScore} '
      '(${sw.elapsedMilliseconds}ms total)',
    );

    return VizCaptureResult(
      vizFaceImageBytes: cropResult.pngBytes,
      faceBoundingBox: largestFace,
      qualityMetrics: qualityMetrics,
    );
  }

  /// Decodes JPEG/PNG bytes using dart:ui's native decoder.
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Rotates a ui.Image by the given angle (degrees) using Canvas.
  Future<ui.Image> _rotateImage(ui.Image image, int angleDegrees) async {
    final radians = angleDegrees * 3.141592653589793 / 180;

    // Calculate rotated dimensions
    final int newWidth;
    final int newHeight;
    if (angleDegrees == 90 || angleDegrees == 270) {
      newWidth = image.height;
      newHeight = image.width;
    } else if (angleDegrees == 180) {
      newWidth = image.width;
      newHeight = image.height;
    } else {
      newWidth = image.width;
      newHeight = image.height;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
    );

    canvas.translate(newWidth / 2, newHeight / 2);
    canvas.rotate(radians);
    canvas.translate(-image.width / 2, -image.height / 2);
    canvas.drawImage(image, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final rotated = await picture.toImage(newWidth, newHeight);
    picture.dispose();
    return rotated;
  }

  /// Selects the main passport photo face from detected faces.
  ///
  /// Uses a scoring system that considers both face size and horizontal
  /// position. ICAO 9303 passport photos are always on the left side of
  /// the data page, so faces in the left portion of the image receive a
  /// scoring bonus. This avoids selecting ghost images (smaller, typically
  /// on the right) on polycarbonate passports.
  Rect _selectMainFace(List<Rect> faces, {required double imageWidth}) {
    if (faces.length == 1) return faces.first;

    _log.info('Multiple faces detected (${faces.length}), '
        'applying position-aware selection');

    Rect best = faces.first;
    double bestScore = -1;

    for (final face in faces) {
      final area = face.width * face.height;
      final centerX = face.left + face.width / 2;
      // Faces in the left 40% of the image get a 1.5x area bonus.
      // Main photo is always left; ghost needs >1.5x area to "win".
      final multiplier = (centerX / imageWidth) < 0.4 ? 1.5 : 1.0;
      final score = area * multiplier;

      if (score > bestScore) {
        bestScore = score;
        best = face;
      }
    }

    _log.info('Selected face: ${best.left.toInt()},${best.top.toInt()} '
        '${best.width.toInt()}x${best.height.toInt()}');
    return best;
  }

  /// Crops the face region with 20% padding using dart:ui Canvas.
  ///
  /// Returns both PNG bytes (for storage/display) and raw RGBA pixels
  /// (for quality analysis without re-decoding).
  Future<_CropResult?> _cropFace(ui.Image fullImage, Rect faceRect) async {
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

    // Draw the cropped region onto a new image using Canvas
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()),
    );
    canvas.drawImageRect(
      fullImage,
      Rect.fromLTWH(
          x.toDouble(), y.toDouble(), cropWidth.toDouble(), cropHeight.toDouble()),
      Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(cropWidth, cropHeight);
    picture.dispose();

    // Extract both PNG bytes and raw RGBA pixels
    final pngData =
        await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    final rgbaData =
        await croppedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    croppedImage.dispose();

    if (pngData == null || rgbaData == null) return null;

    return _CropResult(
      pngBytes: Uint8List.view(pngData.buffer),
      rgbaPixels: rgbaData,
      width: cropWidth,
      height: cropHeight,
    );
  }
}

/// Internal result from face cropping containing both encoded and raw pixels.
class _CropResult {
  final Uint8List pngBytes;
  final ByteData rgbaPixels;
  final int width;
  final int height;

  _CropResult({
    required this.pngBytes,
    required this.rgbaPixels,
    required this.width,
    required this.height,
  });
}
