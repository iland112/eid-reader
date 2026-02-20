import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/mrz_input/presentation/providers/mrz_input_provider.dart';

void main() {
  group('MrzInputState', () {
    test('default values are empty strings', () {
      const state = MrzInputState();
      expect(state.documentNumber, '');
      expect(state.dateOfBirth, '');
      expect(state.dateOfExpiry, '');
    });

    test('copyWith updates only specified fields', () {
      const state = MrzInputState();
      final updated = state.copyWith(documentNumber: 'ABC');
      expect(updated.documentNumber, 'ABC');
      expect(updated.dateOfBirth, '');
      expect(updated.dateOfExpiry, '');
    });

    test('copyWith preserves unchanged fields', () {
      const state = MrzInputState(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      final updated = state.copyWith(dateOfBirth: '900101');
      expect(updated.documentNumber, 'L898902C');
      expect(updated.dateOfBirth, '900101');
      expect(updated.dateOfExpiry, '940623');
    });

    test('toMrzData uppercases document number', () {
      const state = MrzInputState(
        documentNumber: 'abc123',
        dateOfBirth: '900101',
        dateOfExpiry: '300101',
      );
      final mrzData = state.toMrzData();
      expect(mrzData.documentNumber, 'ABC123');
      expect(mrzData.dateOfBirth, '900101');
      expect(mrzData.dateOfExpiry, '300101');
    });

    test('toMrzData returns MrzData instance', () {
      const state = MrzInputState(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      expect(state.toMrzData(), isA<MrzData>());
    });
  });

  group('MrzInputNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has empty fields', () {
      final state = container.read(mrzInputProvider);
      expect(state.documentNumber, '');
      expect(state.dateOfBirth, '');
      expect(state.dateOfExpiry, '');
    });

    test('updateDocumentNumber updates state', () {
      container.read(mrzInputProvider.notifier).updateDocumentNumber('L898');
      expect(container.read(mrzInputProvider).documentNumber, 'L898');
    });

    test('updateDateOfBirth updates state', () {
      container.read(mrzInputProvider.notifier).updateDateOfBirth('690806');
      expect(container.read(mrzInputProvider).dateOfBirth, '690806');
    });

    test('updateDateOfExpiry updates state', () {
      container.read(mrzInputProvider.notifier).updateDateOfExpiry('940623');
      expect(container.read(mrzInputProvider).dateOfExpiry, '940623');
    });

    test('setFromMrz populates all fields', () {
      const mrzData = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      container.read(mrzInputProvider.notifier).setFromMrz(mrzData);
      final state = container.read(mrzInputProvider);
      expect(state.documentNumber, 'L898902C');
      expect(state.dateOfBirth, '690806');
      expect(state.dateOfExpiry, '940623');
    });

    test('multiple updates accumulate correctly', () {
      final notifier = container.read(mrzInputProvider.notifier);
      notifier.updateDocumentNumber('AB123');
      notifier.updateDateOfBirth('900101');
      notifier.updateDateOfExpiry('300101');

      final state = container.read(mrzInputProvider);
      expect(state.documentNumber, 'AB123');
      expect(state.dateOfBirth, '900101');
      expect(state.dateOfExpiry, '300101');
    });
  });
}
