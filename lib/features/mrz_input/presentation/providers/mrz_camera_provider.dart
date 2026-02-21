import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/services/face_detection_service.dart';
import '../../../../core/services/image_quality_analyzer.dart';
import '../../../passport_reader/domain/usecases/capture_viz_face.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/entities/viz_capture_result.dart';
import '../../domain/usecases/parse_mrz_from_text.dart';

/// VIZ capture status during MRZ + VIZ camera session.
enum VizCaptureStatus {
  idle,
  detectingFace,
  ready,
  noFace,
  error,
}

/// State for MRZ camera scanning.
class MrzCameraState {
  final bool isProcessing;
  final MrzData? detectedMrz;
  final String? errorMessage;
  final String? debugOcrText;
  final int debugFrameCount;
  final VizCaptureResult? vizCapture;
  final VizCaptureStatus vizCaptureStatus;

  const MrzCameraState({
    this.isProcessing = false,
    this.detectedMrz,
    this.errorMessage,
    this.debugOcrText,
    this.debugFrameCount = 0,
    this.vizCapture,
    this.vizCaptureStatus = VizCaptureStatus.idle,
  });

  MrzCameraState copyWith({
    bool? isProcessing,
    MrzData? detectedMrz,
    String? errorMessage,
    String? debugOcrText,
    int? debugFrameCount,
    VizCaptureResult? vizCapture,
    VizCaptureStatus? vizCaptureStatus,
  }) {
    return MrzCameraState(
      isProcessing: isProcessing ?? this.isProcessing,
      detectedMrz: detectedMrz ?? this.detectedMrz,
      errorMessage: errorMessage,
      debugOcrText: debugOcrText ?? this.debugOcrText,
      debugFrameCount: debugFrameCount ?? this.debugFrameCount,
      vizCapture: vizCapture ?? this.vizCapture,
      vizCaptureStatus: vizCaptureStatus ?? this.vizCaptureStatus,
    );
  }
}

/// Abstraction for text recognition to enable testing.
abstract class TextRecognitionService {
  Future<String> recognizeText(InputImage image);
  void close();
}

/// Default implementation using Google ML Kit.
class MlKitTextRecognitionService implements TextRecognitionService {
  final TextRecognizer _recognizer = TextRecognizer();

  @override
  Future<String> recognizeText(InputImage image) async {
    final result = await _recognizer.processImage(image);
    return result.text;
  }

  @override
  void close() {
    _recognizer.close();
  }
}

class MrzCameraNotifier extends StateNotifier<MrzCameraState> {
  final TextRecognitionService _recognitionService;
  final ParseMrzFromText _parser;
  final CaptureVizFace? _captureVizFace;

  /// Multi-frame consensus: accumulate matching parses before confirming.
  final List<MrzData> _candidates = [];

  /// Number of matching parses required for consensus.
  final int consensusCount;

  MrzCameraNotifier({
    TextRecognitionService? recognitionService,
    ParseMrzFromText? parser,
    CaptureVizFace? captureVizFace,
    this.consensusCount = 3,
  })  : _recognitionService =
            recognitionService ?? MlKitTextRecognitionService(),
        _parser = parser ?? ParseMrzFromText(),
        _captureVizFace = captureVizFace,
        super(const MrzCameraState());

  /// Process a camera frame for MRZ detection.
  Future<void> processImage(InputImage image) async {
    // Skip if already processing or MRZ already detected
    if (state.isProcessing || state.detectedMrz != null) return;

    final frameCount = state.debugFrameCount + 1;
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final text = await _recognitionService.recognizeText(image);
      final mrzData = _parser.parse(text);

      // Build debug info: show OCR text and candidate line info
      final debugInfo = StringBuffer();
      debugInfo.writeln('[Frame #$frameCount] OCR chars: ${text.length}');
      final lines = text.split(RegExp(r'[\n\r]+'));
      final longLines = lines
          .where((l) => l.replaceAll(' ', '').length >= 30)
          .toList();
      debugInfo.writeln('Lines: ${lines.length}, long(>=30): ${longLines.length}');
      for (final l in longLines.take(4)) {
        final cleaned = l.replaceAll(' ', '');
        debugInfo.writeln('[${cleaned.length}] ${cleaned.length > 50 ? '${cleaned.substring(0, 50)}...' : cleaned}');
      }

      if (mrzData != null) {
        _candidates.add(mrzData);

        // Check consensus: same core fields (docNum, DOB, DOE) N times
        final consensusMrz = _checkConsensus();
        if (consensusMrz != null) {
          state = MrzCameraState(
            detectedMrz: consensusMrz,
            debugOcrText: debugInfo.toString(),
            debugFrameCount: frameCount,
            vizCaptureStatus: VizCaptureStatus.idle,
          );
        } else {
          debugInfo.writeln(
              'Consensus: ${_candidates.length}/$consensusCount');
          state = MrzCameraState(
            debugOcrText: debugInfo.toString(),
            debugFrameCount: frameCount,
          );
        }
      } else {
        state = MrzCameraState(
          debugOcrText: debugInfo.toString(),
          debugFrameCount: frameCount,
        );
      }
    } catch (e) {
      state = MrzCameraState(
        debugOcrText: '[Frame #$frameCount] Error: $e',
        debugFrameCount: frameCount,
      );
    }
  }

  /// Captures VIZ face from a high-resolution still image.
  ///
  /// Called after MRZ detection when takePicture() captures a still frame.
  /// [imageBytes] - JPEG bytes from camera takePicture().
  /// [inputImage] - InputImage for ML Kit face detection.
  Future<void> captureViz({
    required Uint8List imageBytes,
    required InputImage inputImage,
  }) async {
    if (_captureVizFace == null) return;

    state = state.copyWith(
      vizCaptureStatus: VizCaptureStatus.detectingFace,
    );

    try {
      final vizResult = await _captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
      );

      if (vizResult != null) {
        // Attach VIZ capture to the detected MRZ data
        final mrzWithViz = state.detectedMrz?.withVizCapture(vizResult);
        state = MrzCameraState(
          detectedMrz: mrzWithViz ?? state.detectedMrz,
          debugOcrText: state.debugOcrText,
          debugFrameCount: state.debugFrameCount,
          vizCapture: vizResult,
          vizCaptureStatus: VizCaptureStatus.ready,
        );
      } else {
        state = state.copyWith(
          vizCaptureStatus: VizCaptureStatus.noFace,
        );
      }
    } catch (e) {
      state = state.copyWith(
        vizCaptureStatus: VizCaptureStatus.error,
      );
    }

    // Security: zero the full page image bytes after processing
    imageBytes.fillRange(0, imageBytes.length, 0);
  }

  /// Process raw OCR text for MRZ detection (for testing without InputImage).
  void processText(String text) {
    final mrzData = _parser.parse(text);
    if (mrzData != null) {
      state = MrzCameraState(detectedMrz: mrzData);
    }
  }

  /// Checks if enough candidates agree on the same core MRZ fields.
  /// Returns the most recent matching candidate (which has the richest data).
  MrzData? _checkConsensus() {
    if (_candidates.length < consensusCount) return null;

    // Count occurrences of each (docNum, DOB, DOE) tuple
    final counts = <String, int>{};
    for (final c in _candidates) {
      final key =
          '${c.documentNumber}|${c.dateOfBirth}|${c.dateOfExpiry}';
      counts[key] = (counts[key] ?? 0) + 1;
    }

    // Find the first key that reaches consensus
    for (final entry in counts.entries) {
      if (entry.value >= consensusCount) {
        // Return the most recent candidate with this key
        for (int i = _candidates.length - 1; i >= 0; i--) {
          final c = _candidates[i];
          final key =
              '${c.documentNumber}|${c.dateOfBirth}|${c.dateOfExpiry}';
          if (key == entry.key) return c;
        }
      }
    }
    return null;
  }

  /// Reset state for re-scanning.
  void reset() {
    _candidates.clear();
    state = const MrzCameraState();
  }

  @override
  void dispose() {
    _recognitionService.close();
    super.dispose();
  }
}

final mrzCameraProvider =
    StateNotifierProvider<MrzCameraNotifier, MrzCameraState>((ref) {
  final captureVizFace = ref.watch(captureVizFaceProvider);
  return MrzCameraNotifier(captureVizFace: captureVizFace);
});

/// Provider for CaptureVizFace use case.
final captureVizFaceProvider = Provider<CaptureVizFace?>((ref) {
  final faceDetection = ref.watch(faceDetectionServiceProvider);
  final qualityAnalyzer = ref.watch(imageQualityAnalyzerProvider);
  if (faceDetection == null) return null;
  return CaptureVizFace(
    faceDetection: faceDetection,
    qualityAnalyzer: qualityAnalyzer,
  );
});

/// Provider for face detection service (null on desktop).
final faceDetectionServiceProvider = Provider<FaceDetectionService?>((ref) {
  return MlKitFaceDetectionService();
});

/// Provider for image quality analyzer.
final imageQualityAnalyzerProvider = Provider<ImageQualityAnalyzer>((ref) {
  return DefaultImageQualityAnalyzer();
});
