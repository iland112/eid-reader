import 'dart:typed_data';
import 'dart:ui';

import '../../../passport_reader/domain/entities/image_quality_metrics.dart';

/// Result of capturing and processing the VIZ (Visual Inspection Zone)
/// from the passport data page via camera.
class VizCaptureResult {
  /// Cropped face image bytes (JPEG) extracted from the VIZ.
  final Uint8List vizFaceImageBytes;

  /// Bounding box of the detected face within the full page image.
  final Rect faceBoundingBox;

  /// Image quality metrics for the captured face region.
  final ImageQualityMetrics qualityMetrics;

  const VizCaptureResult({
    required this.vizFaceImageBytes,
    required this.faceBoundingBox,
    required this.qualityMetrics,
  });
}
