import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/passport_reader/data/datasources/passport_datasource.dart';
import 'package:eid_reader/features/passport_reader/data/datasources/passport_read_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/passport_data.dart';
import 'package:eid_reader/features/passport_reader/presentation/providers/passport_reader_provider.dart';
import 'package:eid_reader/features/passport_reader/presentation/screens/nfc_scan_screen.dart';

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

/// A mock datasource that uses Completer for fine-grained control.
class MockPassportDatasource implements PassportDatasource {
  PassportReadResult? _result;
  Object? _error;
  Completer<void>? _blocker;

  /// Configure to block indefinitely (for "in progress" state tests).
  void mockBlock() {
    _blocker = Completer<void>();
    _result = null;
    _error = null;
  }

  void mockSuccess(PassportReadResult result) {
    _result = result;
    _error = null;
    _blocker = null;
  }

  void mockError(Object error) {
    _error = error;
    _result = null;
    _blocker = null;
  }

  @override
  Future<PassportReadResult> readPassport(MrzData mrzData) async {
    if (_blocker != null) {
      await _blocker!.future;
    }
    if (_error != null) throw _error!;
    return _result!;
  }
}

/// Builds a testable widget with GoRouter (for named route navigation)
/// and provider overrides.
Widget _buildTestApp({
  required PassportDatasource datasource,
}) {
  final router = GoRouter(
    initialLocation: '/nfc-scan',
    routes: [
      GoRoute(
        path: '/nfc-scan',
        name: 'nfc-scan',
        builder: (context, state) =>
            const NfcScanScreen(mrzData: _testMrzData),
      ),
      GoRoute(
        path: '/passport-detail',
        name: 'passport-detail',
        builder: (context, state) =>
            const Scaffold(body: Text('Passport Detail')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      passportReaderProvider.overrideWith(
        (ref) => PassportReaderNotifier(datasource: datasource),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  group('NfcScanScreen', () {
    testWidgets('renders app bar title', (tester) async {
      final mock = MockPassportDatasource()..mockBlock();

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();

      expect(find.text('Scanning Passport'), findsOneWidget);
    });

    testWidgets('shows contactless icon during reading', (tester) async {
      final mock = MockPassportDatasource()..mockBlock();

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();

      expect(find.byIcon(Icons.contactless), findsOneWidget);
    });

    testWidgets('shows step indicator during reading', (tester) async {
      final mock = MockPassportDatasource()..mockBlock();

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();

      // Step indicator labels
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Auth'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('shows positioning guide during connecting', (tester) async {
      final mock = MockPassportDatasource()..mockBlock();

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();

      expect(
        find.text('Place phone flat on the passport data page'),
        findsOneWidget,
      );
    });

    testWidgets('shows error message on TagLost', (tester) async {
      final mock = MockPassportDatasource()
        ..mockError(Exception('TagLost'));

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
            'Connection lost. Keep your phone still against the passport and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows Retry button on error', (tester) async {
      final mock = MockPassportDatasource()
        ..mockError(Exception('TagLost'));

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows authentication error message', (tester) async {
      final mock = MockPassportDatasource()
        ..mockError(Exception('SecurityStatusNotSatisfied'));

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
            'Authentication failed. Please check your passport details.'),
        findsOneWidget,
      );
    });

    testWidgets('shows timeout error message', (tester) async {
      final mock = MockPassportDatasource()
        ..mockError(Exception('timeout'));

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Reading timed out. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows generic error for unknown exceptions', (tester) async {
      final mock = MockPassportDatasource()
        ..mockError(Exception('xyz'));

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
            'Could not read passport. Please reposition and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('navigates to passport-detail on success', (tester) async {
      final mock = MockPassportDatasource()..mockSuccess(_testReadResult);

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();
      // Wait for the 400ms navigation delay + animation
      await tester.pumpAndSettle();

      // Should navigate to passport-detail route
      expect(find.text('Passport Detail'), findsOneWidget);
    });

    testWidgets('Retry button retriggers reading and navigates on success',
        (tester) async {
      final mock = MockPassportDatasource()
        ..mockError(Exception('TagLost'));

      await tester.pumpWidget(_buildTestApp(datasource: mock));
      await tester.pump();
      await tester.pump();

      // Verify error state
      expect(find.textContaining('Retry'), findsOneWidget);

      // Now mock success for retry
      mock.mockSuccess(_testReadResult);

      await tester.tap(find.textContaining('Retry'));
      await tester.pumpAndSettle();

      // Should navigate to passport-detail route
      expect(find.text('Passport Detail'), findsOneWidget);
    });
  });
}
