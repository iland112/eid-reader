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
      expect(state.cameraMrzData, isNull);
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

    test('toMrzData uses cameraMrzData when core fields match', () {
      const cameraMrz = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
        surname: 'ERIKSSON',
        givenNames: 'ANNA MARIA',
        nationality: 'UTO',
        sex: 'F',
        mrzLine1: 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
        mrzLine2: 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14',
      );
      const state = MrzInputState(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
        cameraMrzData: cameraMrz,
      );
      final result = state.toMrzData();
      expect(result.surname, 'ERIKSSON');
      expect(result.givenNames, 'ANNA MARIA');
      expect(result.nationality, 'UTO');
      expect(result.sex, 'F');
      expect(result.mrzLine1, isNotNull);
    });

    test('toMrzData falls back to basic MrzData when fields differ', () {
      const cameraMrz = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
        surname: 'ERIKSSON',
      );
      const state = MrzInputState(
        documentNumber: 'X999999',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
        cameraMrzData: cameraMrz,
      );
      final result = state.toMrzData();
      expect(result.documentNumber, 'X999999');
      expect(result.surname, isNull);
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

    test('setFromMrz preserves cameraMrzData', () {
      const mrzData = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
        surname: 'ERIKSSON',
        nationality: 'UTO',
      );
      container.read(mrzInputProvider.notifier).setFromMrz(mrzData);
      final state = container.read(mrzInputProvider);
      expect(state.cameraMrzData, isNotNull);
      expect(state.cameraMrzData!.surname, 'ERIKSSON');
      expect(state.cameraMrzData!.nationality, 'UTO');
    });

    test('toMrzData preserves camera fields after setFromMrz', () {
      const mrzData = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
        surname: 'ERIKSSON',
        givenNames: 'ANNA',
        mrzLine1: 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
      );
      container.read(mrzInputProvider.notifier).setFromMrz(mrzData);
      final result = container.read(mrzInputProvider).toMrzData();
      expect(result.surname, 'ERIKSSON');
      expect(result.givenNames, 'ANNA');
      expect(result.mrzLine1, isNotNull);
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
