import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/mrz_input/presentation/providers/mrz_input_provider.dart';
import 'package:eid_reader/features/mrz_input/presentation/screens/mrz_input_screen.dart';

final bool _isDesktop =
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
            path: '/scan',
            name: 'scan',
            builder: (context, state) =>
                const Scaffold(body: Text('Scan')),
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

    testWidgets('renders instruction text when no camera data',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      if (_isDesktop) {
        expect(
          find.text(
              'Enter passport MRZ data to read the e-Passport chip.'),
          findsOneWidget,
        );
      } else {
        expect(
          find.text(
              'Scan the passport VIZ, or enter MRZ data manually.'),
          findsOneWidget,
        );
      }
    });

    testWidgets('renders three text fields', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Document Number'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Date of Expiry'), findsOneWidget);
    });

    testWidgets('renders scan button with platform-appropriate label',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      if (_isDesktop) {
        expect(find.text('Read with Card Reader'), findsOneWidget);
        expect(find.byIcon(Icons.usb), findsOneWidget);
      } else {
        expect(find.text('Scan Passport'), findsOneWidget);
        expect(find.byIcon(Icons.contactless), findsOneWidget);
      }
    });

    testWidgets('shows validation errors when submitting empty form',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Scroll to and tap submit button with empty fields
      final buttonText =
          _isDesktop ? 'Read with Card Reader' : 'Scan Passport';
      await tester.ensureVisible(find.text(buttonText));
      await tester.pumpAndSettle();
      await tester.tap(find.text(buttonText));
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

      final buttonText =
          _isDesktop ? 'Read with Card Reader' : 'Scan Passport';
      await tester.ensureVisible(find.text(buttonText));
      await tester.pumpAndSettle();
      await tester.tap(find.text(buttonText));
      await tester.pumpAndSettle();

      // Date fields should show format error
      expect(find.text('Format: YYMMDD (6 digits)'), findsWidgets);
    });

    testWidgets('navigates to scan with valid input', (tester) async {
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

      // Button text is platform-dependent
      final buttonText =
          _isDesktop ? 'Read with Card Reader' : 'Scan Passport';
      await tester.ensureVisible(find.text(buttonText));
      await tester.pumpAndSettle();
      await tester.tap(find.text(buttonText));
      await tester.pumpAndSettle();

      // Should navigate to scan screen
      expect(find.text('Scan'), findsOneWidget);
    });

    testWidgets('renders platform-appropriate scan button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      if (_isDesktop) {
        // Desktop: 'Read with Card Reader' with USB icon, no camera scan
        expect(find.text('Read with Card Reader'), findsOneWidget);
        expect(find.byIcon(Icons.usb), findsOneWidget);
        expect(find.text('Scan VIZ'), findsNothing);
      } else {
        // Mobile: 'Scan Passport' with NFC icon + 'Scan VIZ' camera button
        expect(find.text('Scan Passport'), findsOneWidget);
        expect(find.byIcon(Icons.contactless), findsOneWidget);
        expect(find.text('Scan VIZ'), findsOneWidget);
      }
    });

    testWidgets('renders field hint texts', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('e.g. M12345678'), findsOneWidget);
      expect(find.text('YYMMDD (e.g. 900115)'), findsOneWidget);
      expect(find.text('YYMMDD (e.g. 300115)'), findsOneWidget);
    });

    testWidgets('renders log share button in debug mode', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byTooltip('Share debug log'), findsOneWidget);
    });

    testWidgets('shows VIZ scan result card when camera data available',
        (tester) async {
      final notifier = MrzInputNotifier();
      notifier.setFromMrz(const MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
        surname: 'ERIKSSON',
        givenNames: 'ANNA MARIA',
        nationality: 'UTO',
        sex: 'F',
        mrzLine1: 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
        mrzLine2: 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14',
      ));

      await tester.pumpWidget(_buildTestApp(
        overrides: [
          mrzInputProvider.overrideWith((ref) => notifier),
        ],
      ));
      await tester.pumpAndSettle();

      // Should show scan result card
      expect(find.text('Scan Result'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner), findsOneWidget);
      expect(find.textContaining('ANNA MARIA ERIKSSON'), findsOneWidget);
      expect(find.textContaining('UTO'), findsWidgets);

      // Hero card should NOT be present
      expect(find.text('Enter Passport MRZ Data'), findsNothing);
      expect(find.byIcon(Icons.credit_card), findsNothing);
    });
  });
}
