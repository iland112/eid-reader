import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Abstraction for face detection to enable testing.
abstract class FaceDetectionService {
  /// Detects faces in the given image and returns bounding boxes.
  Future<List<Rect>> detectFaces(InputImage image);

  /// Releases resources.
  void close();
}

/// Default implementation using Google ML Kit Face Detection.
class MlKitFaceDetectionService implements FaceDetectionService {
  final FaceDetector _detector;

  MlKitFaceDetectionService({double minFaceSize = 0.08})
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableLandmarks: false,
            enableClassification: false,
            enableTracking: false,
            performanceMode: FaceDetectorMode.accurate,
            minFaceSize: minFaceSize,
          ),
        );

  @override
  Future<List<Rect>> detectFaces(InputImage image) async {
    final faces = await _detector.processImage(image);
    return faces
        .map((f) => Rect.fromLTRB(
              f.boundingBox.left,
              f.boundingBox.top,
              f.boundingBox.right,
              f.boundingBox.bottom,
            ))
        .toList();
  }

  @override
  void close() {
    _detector.close();
  }
}
