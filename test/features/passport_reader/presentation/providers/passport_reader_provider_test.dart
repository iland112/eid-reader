import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/passport_reader/data/datasources/passport_datasource.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/passport_data.dart';
import 'package:eid_reader/features/passport_reader/presentation/providers/passport_reader_provider.dart';

/// Manual mock for [PassportDatasource] to avoid build_runner dependency.
class MockPassportDatasource implements PassportDatasource {
  PassportData? _result;
  Object? _error;

  void mockSuccess(PassportData data) {
    _result = data;
    _error = null;
  }

  void mockError(Object error) {
    _error = error;
    _result = null;
  }

  @override
  Future<PassportData> readPassport(MrzData mrzData) async {
    if (_error != null) throw _error!;
    return _result!;
  }
}

const _testMrzData = MrzData(
  documentNumber: 'L898902C',
  dateOfBirth: '690806',
  dateOfExpiry: '940623',
);

const _testPassportData = PassportData(
  surname: 'DOE',
  givenNames: 'JOHN',
  documentNumber: 'L898902C',
  nationality: 'USA',
  dateOfBirth: '690806',
  sex: 'M',
  dateOfExpiry: '940623',
  issuingState: 'USA',
  documentType: 'P',
  authProtocol: 'BAC',
);

void main() {
  group('PassportReaderState', () {
    test('default values', () {
      const state = PassportReaderState();
      expect(state.step, ReadingStep.idle);
      expect(state.data, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith updates step', () {
      const state = PassportReaderState();
      final updated = state.copyWith(step: ReadingStep.connecting);
      expect(updated.step, ReadingStep.connecting);
      expect(updated.data, isNull);
    });

    test('copyWith resets errorMessage to null by default', () {
      const state = PassportReaderState(
        step: ReadingStep.error,
        errorMessage: 'Some error',
      );
      final updated = state.copyWith(step: ReadingStep.idle);
      expect(updated.errorMessage, isNull);
    });
  });

  group('ReadingStep', () {
    test('has all expected values', () {
      expect(ReadingStep.values, containsAll([
        ReadingStep.idle,
        ReadingStep.connecting,
        ReadingStep.authenticating,
        ReadingStep.readingDg1,
        ReadingStep.readingDg2,
        ReadingStep.done,
        ReadingStep.error,
      ]));
    });

    test('has 7 values total', () {
      expect(ReadingStep.values.length, 7);
    });
  });

  group('PassportReaderNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle', () {
      final state = container.read(passportReaderProvider);
      expect(state.step, ReadingStep.idle);
      expect(state.data, isNull);
      expect(state.errorMessage, isNull);
    });

    test('reset returns to idle state', () {
      container.read(passportReaderProvider.notifier).reset();
      final state = container.read(passportReaderProvider);
      expect(state.step, ReadingStep.idle);
      expect(state.data, isNull);
      expect(state.errorMessage, isNull);
    });
  });

  group('PassportReaderNotifier with mock datasource', () {
    late MockPassportDatasource mockDatasource;
    late PassportReaderNotifier notifier;

    setUp(() {
      mockDatasource = MockPassportDatasource();
      notifier = PassportReaderNotifier(datasource: mockDatasource);
    });

    test('readPassport sets done state on success', () async {
      mockDatasource.mockSuccess(_testPassportData);

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.done);
      expect(notifier.state.data, _testPassportData);
      expect(notifier.state.errorMessage, isNull);
    });

    test('readPassport sets error state on TagLost exception', () async {
      mockDatasource.mockError(Exception('TagLost'));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.error);
      expect(notifier.state.data, isNull);
      expect(notifier.state.errorMessage, contains('Connection lost'));
    });

    test('readPassport sets error state on authentication failure', () async {
      mockDatasource.mockError(Exception('SecurityStatusNotSatisfied'));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.error);
      expect(notifier.state.errorMessage, contains('Authentication failed'));
    });

    test('readPassport sets error state on timeout', () async {
      mockDatasource.mockError(Exception('timeout'));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.error);
      expect(notifier.state.errorMessage, contains('timed out'));
    });

    test('readPassport sets generic error for unknown exceptions', () async {
      mockDatasource.mockError(Exception('some unknown error'));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.error);
      expect(notifier.state.errorMessage, contains('Could not read passport'));
    });

    test('reset after readPassport clears state', () async {
      mockDatasource.mockSuccess(_testPassportData);

      await notifier.readPassport(_testMrzData);
      expect(notifier.state.step, ReadingStep.done);

      notifier.reset();
      expect(notifier.state.step, ReadingStep.idle);
      expect(notifier.state.data, isNull);
    });
  });
}
