import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../data/datasources/http_pa_service.dart';
import '../../data/datasources/nfc_passport_datasource.dart';
import '../../data/datasources/pa_service.dart';
import '../../data/datasources/passport_datasource.dart';
import '../../domain/entities/passport_data.dart';

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
  done,
  error,
}

class PassportReaderState {
  final ReadingStep step;
  final PassportData? data;
  final String? errorMessage;

  const PassportReaderState({
    this.step = ReadingStep.idle,
    this.data,
    this.errorMessage,
  });

  PassportReaderState copyWith({
    ReadingStep? step,
    PassportData? data,
    String? errorMessage,
  }) {
    return PassportReaderState(
      step: step ?? this.step,
      data: data ?? this.data,
      errorMessage: errorMessage,
    );
  }
}

class PassportReaderNotifier extends StateNotifier<PassportReaderState> {
  final PassportDatasource _datasource;
  final PaService? _paService;
  final bool _checkNfc;

  PassportReaderNotifier({
    PassportDatasource? datasource,
    PaService? paService,
  })  : _datasource = datasource ?? NfcPassportDatasource(),
        _paService = paService,
        // Only check NFC availability when using the real NFC datasource.
        // When a custom datasource is injected (e.g. for testing), skip the check.
        _checkNfc = datasource == null,
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

      state = state.copyWith(step: ReadingStep.authenticating);
      final readResult = await _datasource.readPassport(mrzData);

      // PA verification (optional - only if PaService is configured)
      var passportData = readResult.passportData;
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

      state = PassportReaderState(
        step: ReadingStep.done,
        data: passportData,
      );
    } catch (e) {
      state = PassportReaderState(
        step: ReadingStep.error,
        errorMessage: _getErrorMessage(e),
      );
    }
  }

  void reset() {
    state = const PassportReaderState();
  }

  String _getErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('TagLost') || message.contains('tag was lost')) {
      return 'Connection lost. Keep your phone still and try again.';
    }
    if (message.contains('SecurityStatusNotSatisfied') ||
        message.contains('authentication')) {
      return 'Authentication failed. Please check your passport details.';
    }
    if (message.contains('timeout') || message.contains('Timeout')) {
      return 'Reading timed out. Please try again.';
    }
    if (message.contains('NFC') || message.contains('nfc')) {
      return 'NFC error. Please make sure NFC is enabled and try again.';
    }
    if (message.contains('poll') || message.contains('Poll')) {
      return 'No passport detected. Hold your phone against the back of the passport.';
    }
    _log.warning('Unhandled error: $message');
    return 'Could not read passport. Please reposition and try again.';
  }
}

/// PA Service base URL provider. Override for custom server address.
final paServiceBaseUrlProvider = Provider<String>((ref) {
  return 'http://10.0.2.2:8080';
});

/// PA Service provider. Returns null if base URL is empty.
final paServiceProvider = Provider<PaService?>((ref) {
  final baseUrl = ref.watch(paServiceBaseUrlProvider);
  if (baseUrl.isEmpty) return null;
  return HttpPaService(baseUrl: baseUrl);
});

final passportReaderProvider =
    StateNotifierProvider<PassportReaderNotifier, PassportReaderState>((ref) {
  final paService = ref.watch(paServiceProvider);
  return PassportReaderNotifier(paService: paService);
});
