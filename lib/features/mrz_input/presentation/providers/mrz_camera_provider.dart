import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';

import '../../../../core/services/face_detection_service.dart';
import '../../../../core/services/image_quality_analyzer.dart';
import '../../../passport_reader/domain/usecases/capture_viz_face.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/entities/viz_capture_result.dart';
import '../../domain/usecases/parse_mrz_from_text.dart';

final _log = Logger('MrzCameraProvider');

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
  final int debugFrameCount;
  final VizCaptureResult? vizCapture;
  final VizCaptureStatus vizCaptureStatus;

  const MrzCameraState({
    this.isProcessing = false,
    this.detectedMrz,
    this.errorMessage,
    this.debugFrameCount = 0,
    this.vizCapture,
    this.vizCaptureStatus = VizCaptureStatus.idle,
  });

  MrzCameraState copyWith({
    bool? isProcessing,
    MrzData? detectedMrz,
    String? errorMessage,
    int? debugFrameCount,
    VizCaptureResult? vizCapture,
    VizCaptureStatus? vizCaptureStatus,
  }) {
    return MrzCameraState(
      isProcessing: isProcessing ?? this.isProcessing,
      detectedMrz: detectedMrz ?? this.detectedMrz,
      errorMessage: errorMessage,
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
    final sw = Stopwatch()..start();

    try {
      final text = await _recognitionService.recognizeText(image);
      final ocrMs = sw.elapsedMilliseconds;

      final mrzData = _parser.parse(text);
      final parseMs = sw.elapsedMilliseconds;

      _log.fine(
        'Frame #$frameCount: OCR=${ocrMs}ms, '
        'parse=${parseMs - ocrMs}ms, '
        'result=${mrzData != null ? "MRZ found" : "no MRZ"}',
      );

      if (mrzData != null) {
        _candidates.add(mrzData);

        // Check consensus: same core fields (docNum, DOB, DOE) N times
        final consensusMrz = _checkConsensus();
        if (consensusMrz != null) {
          _log.info(
            'Consensus reached at frame #$frameCount '
            '(${_candidates.length} candidates, ${parseMs}ms)',
          );
          state = MrzCameraState(
            detectedMrz: consensusMrz,
            debugFrameCount: frameCount,
            vizCaptureStatus: VizCaptureStatus.idle,
          );
        } else {
          state = MrzCameraState(
            debugFrameCount: frameCount,
          );
        }
      } else {
        state = MrzCameraState(
          debugFrameCount: frameCount,
        );
      }
    } catch (e) {
      _log.fine('Frame #$frameCount: error (${sw.elapsedMilliseconds}ms)');
      state = MrzCameraState(
        debugFrameCount: frameCount,
      );
    }
  }

  /// Captures VIZ face from a high-resolution still image.
  ///
  /// Called after MRZ detection when takePicture() captures a still frame.
  /// [imageBytes] - JPEG bytes from camera takePicture().
  /// [inputImage] - InputImage for ML Kit face detection.
  /// [rotationCompensation] - Degrees to rotate raw sensor image to match
  ///   display orientation (computed from sensor + device orientation).
  Future<void> captureViz({
    required Uint8List imageBytes,
    required InputImage inputImage,
    int rotationCompensation = 90,
    Rect? previewFaceRect,
    Size? previewSize,
  }) async {
    if (_captureVizFace == null) {
      _log.warning('captureViz: _captureVizFace is null, skipping');
      return;
    }

    _log.info(
      'captureViz: starting, imageSize=${imageBytes.length} bytes, '
      'rotation=$rotationCompensation',
    );

    state = state.copyWith(
      vizCaptureStatus: VizCaptureStatus.detectingFace,
    );

    try {
      final vizResult = await _captureVizFace.execute(
        imageBytes: imageBytes,
        inputImage: inputImage,
        rotationCompensation: rotationCompensation,
        previewFaceRect: previewFaceRect,
        previewSize: previewSize,
      );

      if (vizResult != null) {
        _log.info(
          'captureViz: face captured, '
          'faceSize=${vizResult.vizFaceImageBytes.length} bytes',
        );
        // Attach VIZ capture to the detected MRZ data
        final mrzWithViz = state.detectedMrz?.withVizCapture(vizResult);
        state = MrzCameraState(
          detectedMrz: mrzWithViz ?? state.detectedMrz,
          debugFrameCount: state.debugFrameCount,
          vizCapture: vizResult,
          vizCaptureStatus: VizCaptureStatus.ready,
        );
      } else {
        _log.info('captureViz: no face found');
        state = state.copyWith(
          vizCaptureStatus: VizCaptureStatus.noFace,
        );
      }
    } catch (e, st) {
      _log.warning('captureViz: error', e, st);
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

    // Find the best count for logging
    int maxCount = 0;
    for (final v in counts.values) {
      if (v > maxCount) maxCount = v;
    }
    _log.fine(
      'Consensus check: ${_candidates.length} candidates, '
      'best=$maxCount/$consensusCount',
    );

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

  /// Marks VIZ capture as failed so the UI can proceed.
  void markVizError() {
    state = state.copyWith(vizCaptureStatus: VizCaptureStatus.error);
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
