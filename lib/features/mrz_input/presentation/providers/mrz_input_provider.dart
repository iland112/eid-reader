import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mrz_data.dart';

/// Holds the current MRZ input state.
class MrzInputState {
  final String documentNumber;
  final String dateOfBirth;
  final String dateOfExpiry;

  const MrzInputState({
    this.documentNumber = '',
    this.dateOfBirth = '',
    this.dateOfExpiry = '',
  });

  MrzInputState copyWith({
    String? documentNumber,
    String? dateOfBirth,
    String? dateOfExpiry,
  }) {
    return MrzInputState(
      documentNumber: documentNumber ?? this.documentNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateOfExpiry: dateOfExpiry ?? this.dateOfExpiry,
    );
  }

  MrzData toMrzData() {
    return MrzData(
      documentNumber: documentNumber.toUpperCase(),
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
    );
  }
}

final mrzInputProvider =
    StateNotifierProvider<MrzInputNotifier, MrzInputState>((ref) {
  return MrzInputNotifier();
});
