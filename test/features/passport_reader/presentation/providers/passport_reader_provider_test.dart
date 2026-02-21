import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/passport_reader/data/datasources/pa_service.dart';
import 'package:eid_reader/features/passport_reader/data/datasources/passport_datasource.dart';
import 'package:eid_reader/features/passport_reader/data/datasources/passport_read_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/pa_verification_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/passport_data.dart';
import 'package:eid_reader/features/passport_reader/presentation/providers/passport_reader_provider.dart';

/// Manual mock for [PassportDatasource] returning [PassportReadResult].
class MockPassportDatasource implements PassportDatasource {
  PassportReadResult? _result;
  Object? _error;

  void mockSuccess(PassportReadResult result) {
    _result = result;
    _error = null;
  }

  void mockError(Object error) {
    _error = error;
    _result = null;
  }

  @override
  Future<PassportReadResult> readPassport(MrzData mrzData) async {
    if (_error != null) throw _error!;
    return _result!;
  }
}

/// Manual mock for [PaService].
class MockPaService implements PaService {
  PaVerificationResult? _result;
  Object? _error;

  void mockSuccess(PaVerificationResult result) {
    _result = result;
    _error = null;
  }

  void mockError(Object error) {
    _error = error;
    _result = null;
  }

  @override
  Future<PaVerificationResult> verify({
    required Uint8List sodBytes,
    required Uint8List dg1Bytes,
    required Uint8List dg2Bytes,
    String? issuingCountry,
    String? documentNumber,
  }) async {
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

final _testReadResult = PassportReadResult(
  passportData: _testPassportData,
  sodBytes: Uint8List.fromList([1, 2, 3]),
  dg1Bytes: Uint8List.fromList([4, 5, 6]),
  dg2Bytes: Uint8List.fromList([7, 8, 9]),
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
        ReadingStep.readingSod,
        ReadingStep.verifyingPa,
        ReadingStep.verifyingViz,
        ReadingStep.done,
        ReadingStep.error,
      ]));
    });

    test('has 10 values total', () {
      expect(ReadingStep.values.length, 10);
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
      mockDatasource.mockSuccess(_testReadResult);

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.done);
      expect(notifier.state.data?.documentNumber, 'L898902C');
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
      mockDatasource.mockSuccess(_testReadResult);

      await notifier.readPassport(_testMrzData);
      expect(notifier.state.step, ReadingStep.done);

      notifier.reset();
      expect(notifier.state.step, ReadingStep.idle);
      expect(notifier.state.data, isNull);
    });
  });

  group('PassportReaderNotifier with PA service', () {
    late MockPassportDatasource mockDatasource;
    late MockPaService mockPaService;
    late PassportReaderNotifier notifier;

    setUp(() {
      mockDatasource = MockPassportDatasource();
      mockPaService = MockPaService();
      notifier = PassportReaderNotifier(
        datasource: mockDatasource,
        paService: mockPaService,
      );
    });

    test('PA verification success sets passiveAuthValid to true', () async {
      mockDatasource.mockSuccess(_testReadResult);
      mockPaService.mockSuccess(const PaVerificationResult(
        status: 'VALID',
        verificationId: 'test-uuid',
        certificateChainValid: true,
        sodSignatureValid: true,
        totalGroups: 2,
        validGroups: 2,
        invalidGroups: 0,
      ));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.done);
      expect(notifier.state.data?.passiveAuthValid, true);
      expect(notifier.state.data?.paVerificationResult?.isValid, true);
      expect(
        notifier.state.data?.paVerificationResult?.verificationId,
        'test-uuid',
      );
    });

    test('PA verification INVALID sets passiveAuthValid to false', () async {
      mockDatasource.mockSuccess(_testReadResult);
      mockPaService.mockSuccess(const PaVerificationResult(
        status: 'INVALID',
        certificateChainValid: false,
      ));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.done);
      expect(notifier.state.data?.passiveAuthValid, false);
      expect(notifier.state.data?.paVerificationResult?.isValid, false);
    });

    test('PA verification failure does not block passport reading', () async {
      mockDatasource.mockSuccess(_testReadResult);
      mockPaService.mockError(Exception('Network timeout'));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.done);
      expect(notifier.state.data?.passiveAuthValid, false);
      expect(notifier.state.data?.paVerificationResult, isNull);
      expect(notifier.state.data?.documentNumber, 'L898902C');
    });

    test('skips PA when SOD bytes are empty', () async {
      final readResultNoSod = PassportReadResult(
        passportData: _testPassportData,
        sodBytes: Uint8List(0),
        dg1Bytes: Uint8List.fromList([4, 5, 6]),
        dg2Bytes: Uint8List.fromList([7, 8, 9]),
      );
      mockDatasource.mockSuccess(readResultNoSod);
      mockPaService.mockSuccess(const PaVerificationResult(status: 'VALID'));

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.done);
      // PA should be skipped because SOD is empty
      expect(notifier.state.data?.passiveAuthValid, false);
      expect(notifier.state.data?.paVerificationResult, isNull);
    });
  });

  group('PassportReaderNotifier without PA service', () {
    late MockPassportDatasource mockDatasource;
    late PassportReaderNotifier notifier;

    setUp(() {
      mockDatasource = MockPassportDatasource();
      notifier = PassportReaderNotifier(datasource: mockDatasource);
    });

    test('works without PA service (null)', () async {
      mockDatasource.mockSuccess(_testReadResult);

      await notifier.readPassport(_testMrzData);

      expect(notifier.state.step, ReadingStep.done);
      expect(notifier.state.data?.passiveAuthValid, false);
      expect(notifier.state.data?.paVerificationResult, isNull);
    });
  });
}
