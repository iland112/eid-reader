import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/mrz_data.dart';
import '../../domain/usecases/parse_mrz_from_text.dart';

/// State for MRZ camera scanning.
class MrzCameraState {
  final bool isProcessing;
  final MrzData? detectedMrz;
  final String? errorMessage;

  const MrzCameraState({
    this.isProcessing = false,
    this.detectedMrz,
    this.errorMessage,
  });

  MrzCameraState copyWith({
    bool? isProcessing,
    MrzData? detectedMrz,
    String? errorMessage,
  }) {
    return MrzCameraState(
      isProcessing: isProcessing ?? this.isProcessing,
      detectedMrz: detectedMrz ?? this.detectedMrz,
      errorMessage: errorMessage,
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

    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final text = await _recognitionService.recognizeText(image);
      final mrzData = _parser.parse(text);

      if (mrzData != null) {
        state = MrzCameraState(detectedMrz: mrzData);
      } else {
        state = const MrzCameraState();
      }
    } catch (e) {
      state = const MrzCameraState();
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
