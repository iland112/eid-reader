import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mrz_data.dart';

/// Holds the current MRZ input state.
class MrzInputState {
  final String documentNumber;
  final String dateOfBirth;
  final String dateOfExpiry;

  /// Full MrzData from camera scan, preserved so all optional fields
  /// (mrzLine1/2, surname, givenNames, nationality, sex, vizCaptureResult)
  /// survive through the navigation flow.
  final MrzData? cameraMrzData;

  const MrzInputState({
    this.documentNumber = '',
    this.dateOfBirth = '',
    this.dateOfExpiry = '',
    this.cameraMrzData,
  });

  MrzInputState copyWith({
    String? documentNumber,
    String? dateOfBirth,
    String? dateOfExpiry,
    MrzData? cameraMrzData,
  }) {
    return MrzInputState(
      documentNumber: documentNumber ?? this.documentNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateOfExpiry: dateOfExpiry ?? this.dateOfExpiry,
      cameraMrzData: cameraMrzData ?? this.cameraMrzData,
    );
  }

  MrzData toMrzData() {
    final docNum = documentNumber.toUpperCase();
    // If we have camera MrzData and the core fields haven't been manually
    // changed, use it to preserve all optional fields + vizCaptureResult.
    if (cameraMrzData != null &&
        cameraMrzData!.documentNumber == docNum &&
        cameraMrzData!.dateOfBirth == dateOfBirth &&
        cameraMrzData!.dateOfExpiry == dateOfExpiry) {
      return cameraMrzData!;
    }
    // Manual entry: only the 3 core fields.
    return MrzData(
      documentNumber: docNum,
      dateOfBirth: dateOfBirth,
      dateOfExpiry: dateOfExpiry,
    );
  }
}

class MrzInputNotifier extends StateNotifier<MrzInputState> {
  MrzInputNotifier() : super(const MrzInputState());

  void updateDocumentNumber(String value) {
    state = state.copyWith(documentNumber: value);
  }

  void updateDateOfBirth(String value) {
    state = state.copyWith(dateOfBirth: value);
  }

  void updateDateOfExpiry(String value) {
    state = state.copyWith(dateOfExpiry: value);
  }

  void setFromMrz(MrzData data) {
    state = MrzInputState(
      documentNumber: data.documentNumber,
      dateOfBirth: data.dateOfBirth,
      dateOfExpiry: data.dateOfExpiry,
      cameraMrzData: data,
    );
  }
}

final mrzInputProvider =
    StateNotifierProvider<MrzInputNotifier, MrzInputState>((ref) {
  return MrzInputNotifier();
});
