import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/mrz_data.dart';
import '../../domain/usecases/parse_mrz_from_text.dart';

/// State for MRZ camera scanning.
class MrzCameraState {
  final bool isProcessing;
  final MrzData? detectedMrz;
  final String? errorMessage;
  final String? debugOcrText;
  final int debugFrameCount;

  const MrzCameraState({
    this.isProcessing = false,
    this.detectedMrz,
    this.errorMessage,
    this.debugOcrText,
    this.debugFrameCount = 0,
  });

  MrzCameraState copyWith({
    bool? isProcessing,
    MrzData? detectedMrz,
    String? errorMessage,
    String? debugOcrText,
    int? debugFrameCount,
  }) {
    return MrzCameraState(
      isProcessing: isProcessing ?? this.isProcessing,
      detectedMrz: detectedMrz ?? this.detectedMrz,
      errorMessage: errorMessage,
      debugOcrText: debugOcrText ?? this.debugOcrText,
      debugFrameCount: debugFrameCount ?? this.debugFrameCount,
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

  MrzCameraNotifier({
    TextRecognitionService? recognitionService,
    ParseMrzFromText? parser,
  })  : _recognitionService =
            recognitionService ?? MlKitTextRecognitionService(),
        _parser = parser ?? ParseMrzFromText(),
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
        state = MrzCameraState(
          detectedMrz: mrzData,
          debugOcrText: debugInfo.toString(),
          debugFrameCount: frameCount,
        );
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

  /// Process raw OCR text for MRZ detection (for testing without InputImage).
  void processText(String text) {
    final mrzData = _parser.parse(text);
    if (mrzData != null) {
      state = MrzCameraState(detectedMrz: mrzData);
    }
  }

  /// Reset state for re-scanning.
  void reset() {
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
  return MrzCameraNotifier();
});
