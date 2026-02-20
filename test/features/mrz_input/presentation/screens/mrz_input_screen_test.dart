import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:eid_reader/features/mrz_input/presentation/screens/mrz_input_screen.dart';

/// Builds a testable widget with ProviderScope and GoRouter.
Widget _buildTestApp({
  List<Override> overrides = const [],
  GoRouter? router,
}) {
  final testRouter = router ??
      GoRouter(
        initialLocation: '/mrz-input',
        routes: [
          GoRoute(
            path: '/mrz-input',
            name: 'mrz-input',
            builder: (context, state) => const MrzInputScreen(),
          ),
          GoRoute(
            path: '/mrz-camera',
            name: 'mrz-camera',
            builder: (context, state) =>
                const Scaffold(body: Text('MRZ Camera')),
          ),
          GoRoute(
            path: '/nfc-scan',
            name: 'nfc-scan',
            builder: (context, state) =>
                const Scaffold(body: Text('NFC Scan')),
          ),
        ],
      );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: testRouter,
    ),
  );
}

void main() {
  group('MrzInputScreen', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('eID Reader'), findsOneWidget);
    });

    testWidgets('renders headline text', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Enter Passport MRZ Data'), findsOneWidget);
    });

    testWidgets('renders three text fields', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Document Number'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Date of Expiry'), findsOneWidget);
    });

    testWidgets('renders Read Passport button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Read Passport'), findsOneWidget);
      expect(find.byIcon(Icons.nfc), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap Read Passport with empty fields
      await tester.tap(find.text('Read Passport'));
      await tester.pumpAndSettle();

      expect(find.text('Document number is required'), findsOneWidget);
      expect(find.text('Date of birth is required'), findsOneWidget);
      expect(find.text('Date of expiry is required'), findsOneWidget);
    });

    testWidgets('shows date format error for partial input', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Enter partial date
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Document Number'),
        'L898902C',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Date of Birth'),
        '690',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Date of Expiry'),
        '940',
      );

      await tester.tap(find.text('Read Passport'));
      await tester.pumpAndSettle();

      // Date fields should show format error
      expect(find.text('Format: YYMMDD (6 digits)'), findsWidgets);
    });

    testWidgets('navigates to nfc-scan with valid input', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Enter valid data
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Document Number'),
        'L898902C',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Date of Birth'),
        '690806',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Date of Expiry'),
        '940623',
      );

      await tester.tap(find.text('Read Passport'));
      await tester.pumpAndSettle();

      // Should navigate to NFC Scan screen
      expect(find.text('NFC Scan'), findsOneWidget);
    });

    testWidgets('renders Scan MRZ button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Scan MRZ'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('Scan MRZ button navigates to mrz-camera', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan MRZ'));
      await tester.pumpAndSettle();

      expect(find.text('MRZ Camera'), findsOneWidget);
    });

    testWidgets('renders credit card icon', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.credit_card), findsOneWidget);
    });

    testWidgets('renders field hint texts', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('e.g. M12345678'), findsOneWidget);
      expect(find.text('YYMMDD (e.g. 900115)'), findsOneWidget);
      expect(find.text('YYMMDD (e.g. 300115)'), findsOneWidget);
    });
  });
}
