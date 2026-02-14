import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../data/datasources/nfc_passport_datasource.dart';
import '../../domain/entities/passport_data.dart';

/// Reading progress state.
enum ReadingStep {
  idle,
  connecting,
  authenticating,
  readingDg1,
  readingDg2,
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
  PassportReaderNotifier() : super(const PassportReaderState());

  final _datasource = NfcPassportDatasource();

  Future<void> readPassport(MrzData mrzData) async {
    state = const PassportReaderState(step: ReadingStep.connecting);

    try {
      state = state.copyWith(step: ReadingStep.authenticating);
      final passportData = await _datasource.readPassport(mrzData);
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
    return 'Could not read passport. Please reposition and try again.';
  }
}

final passportReaderProvider =
    StateNotifierProvider<PassportReaderNotifier, PassportReaderState>((ref) {
  return PassportReaderNotifier();
});
