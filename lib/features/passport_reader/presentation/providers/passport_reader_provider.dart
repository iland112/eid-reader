import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../../core/services/face_embedding_service.dart';
import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../data/datasources/http_pa_service.dart';
import '../../data/datasources/pa_service.dart';
import '../../data/datasources/passport_datasource.dart';
import '../../data/datasources/passport_datasource_factory.dart';
import '../../domain/entities/passport_data.dart';
import '../../domain/usecases/verify_viz.dart';

final _log = Logger('PassportReaderNotifier');

/// Reading progress state.
enum ReadingStep {
  idle,
  connecting,
  authenticating,
  readingDg1,
  readingDg2,
  readingSod,
  verifyingPa,
  verifyingViz,
  done,
  error,
}

class PassportReaderState {
  final ReadingStep step;
  final PassportData? data;
  final String? errorMessage;
  final String? debugError;

  /// NFC step timings in ms (for diagnostics).
  final Map<String, int> stepTimings;

  const PassportReaderState({
    this.step = ReadingStep.idle,
    this.data,
    this.errorMessage,
    this.debugError,
    this.stepTimings = const {},
  });

  PassportReaderState copyWith({
    ReadingStep? step,
    PassportData? data,
    String? errorMessage,
    String? debugError,
    Map<String, int>? stepTimings,
  }) {
    return PassportReaderState(
      step: step ?? this.step,
      data: data ?? this.data,
      errorMessage: errorMessage,
      debugError: debugError,
      stepTimings: stepTimings ?? this.stepTimings,
    );
  }
}

class PassportReaderNotifier extends StateNotifier<PassportReaderState> {
  final PassportDatasource _datasource;
  final PaService? _paService;
  final VerifyViz? _verifyViz;
  final bool _checkNfc;

  PassportReaderNotifier({
    PassportDatasource? datasource,
    PaService? paService,
    VerifyViz? verifyViz,
  })  : _datasource = datasource ?? PassportDatasourceFactory.create(),
        _paService = paService,
        _verifyViz = verifyViz,
        // Only check NFC on Android when using the default datasource.
        _checkNfc = datasource == null && PassportDatasourceFactory.isNfcPlatform,
        super(const PassportReaderState());

  Future<void> readPassport(MrzData mrzData) async {
    state = const PassportReaderState(step: ReadingStep.connecting);

    try {
      // Check NFC availability before attempting to read
      if (_checkNfc) {
        final nfcAvailability = await FlutterNfcKit.nfcAvailability;
        if (nfcAvailability == NFCAvailability.not_supported) {
          state = const PassportReaderState(
            step: ReadingStep.error,
            errorMessage:
                'NFC is not supported on this device.',
          );
          return;
        }
        if (nfcAvailability == NFCAvailability.disabled) {
          state = const PassportReaderState(
            step: ReadingStep.error,
            errorMessage:
                'NFC is disabled. Please enable NFC in your device settings.',
          );
          return;
        }
      }

      // Stay on 'connecting' step – the datasource internally handles
      // NFC polling (connect) + authentication + DG reads.  The UI shows
      // "Hold your phone against the back of the passport" during this time.
      final readResult = await _datasource.readPassport(mrzData);

      // Attach timing data to passport data for debug display
      var passportData = readResult.passportData.copyWith(
        debugTimings: readResult.stepTimings,
      );
      if (_paService != null &&
          readResult.sodBytes.isNotEmpty &&
          readResult.dg1Bytes.isNotEmpty) {
        state = state.copyWith(step: ReadingStep.verifyingPa);
        try {
          final paResult = await _paService.verify(
            sodBytes: readResult.sodBytes,
            dg1Bytes: readResult.dg1Bytes,
            dg2Bytes: readResult.dg2Bytes,
            issuingCountry: passportData.issuingState,
            documentNumber: passportData.documentNumber,
          );
          passportData = passportData.copyWith(
            passiveAuthValid: paResult.isValid,
            paVerificationResult: paResult,
          );
        } catch (e) {
          _log.warning('PA verification failed: $e');
        }
      }

      // VIZ verification (if VIZ face was captured from camera)
      if (_verifyViz != null && mrzData.vizCaptureResult != null) {
        state = state.copyWith(step: ReadingStep.verifyingViz);
        try {
          final vizResult = await _verifyViz.execute(
            vizCapture: mrzData.vizCaptureResult!,
            chipData: passportData,
            ocrMrzData: mrzData,
          );
          passportData = passportData.copyWith(
            faceComparisonResult: vizResult.faceComparison,
            vizMrzFieldsMatch: vizResult.mrzFieldsMatch,
            vizMrzFieldComparison: vizResult.fieldComparison,
            vizImageQuality: mrzData.vizCaptureResult!.qualityMetrics,
            vizFaceBytes: mrzData.vizCaptureResult!.vizFaceImageBytes,
          );
        } catch (e) {
          _log.warning('VIZ verification failed: $e');
          // VIZ failure is non-fatal
        }
      }

      state = PassportReaderState(
        step: ReadingStep.done,
        data: passportData,
        stepTimings: readResult.stepTimings,
      );
    } catch (e) {
      _log.warning('readPassport error: $e');
      state = PassportReaderState(
        step: ReadingStep.error,
        errorMessage: _getErrorMessage(e),
        debugError: e.toString(),
      );
    }
  }

  void reset() {
    state = const PassportReaderState();
  }

  String _getErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('TagLost') ||
        message.contains('tag was lost') ||
        message.contains('CommunicationError')) {
      return 'Connection lost. Keep your phone still against the passport and try again.';
    }
    if (message.contains('SecurityStatusNotSatisfied') ||
        message.contains('authentication')) {
      return 'Authentication failed. Please check your passport details.';
    }
    if (message.contains('Polling tag timeout') ||
        message.contains('poll') ||
        message.contains('Poll')) {
      return 'Passport not detected. Place your phone flat on the '
          'passport data page and hold still.';
    }
    if (message.contains('timeout') || message.contains('Timeout')) {
      return 'Reading timed out. Please try again.';
    }
    if (message.contains('NFC') || message.contains('nfc')) {
      return 'Scan error. Please make sure NFC is enabled and try again.';
    }
    _log.warning('Unhandled error: $message');
    return 'Could not read passport. Please reposition and try again.';
  }
}

/// PA Service base URL provider. Override for custom server address.
final paServiceBaseUrlProvider = Provider<String>((ref) {
  return 'http://192.168.1.43:18080';
});

/// PA Service provider. Returns null if base URL is empty.
final paServiceProvider = Provider<PaService?>((ref) {
  final baseUrl = ref.watch(paServiceBaseUrlProvider);
  if (baseUrl.isEmpty) return null;
  return HttpPaService(baseUrl: baseUrl);
});

/// Face embedding service provider (for VIZ face comparison).
final faceEmbeddingServiceProvider = Provider<FaceEmbeddingService?>((ref) {
  return TfLiteFaceEmbeddingService();
});

/// VIZ verification use case provider.
final verifyVizProvider = Provider<VerifyViz?>((ref) {
  final embeddingService = ref.watch(faceEmbeddingServiceProvider);
  if (embeddingService == null) return null;
  return VerifyViz(embeddingService: embeddingService);
});

final passportReaderProvider =
    StateNotifierProvider<PassportReaderNotifier, PassportReaderState>((ref) {
  final paService = ref.watch(paServiceProvider);
  final verifyViz = ref.watch(verifyVizProvider);
  return PassportReaderNotifier(paService: paService, verifyViz: verifyViz);
});
