import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:eid_reader/app/device_capability_provider.dart';
import 'package:eid_reader/features/landing/presentation/screens/landing_screen.dart';

Widget _buildTestApp({
  Locale locale = const Locale('en'),
  ThemeData? theme,
  GoRouter? router,
  ChipReaderCapability capability = ChipReaderCapability.nfcEnabled,
}) {
  final testRouter = router ??
      GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            name: 'landing',
            builder: (context, state) => const LandingScreen(),
          ),
          GoRoute(
            path: '/mrz-input',
            name: 'mrz-input',
            builder: (context, state) =>
                const Scaffold(body: Text('MRZ Input')),
          ),
        ],
      );

  return ProviderScope(
    overrides: [
      chipReaderCapabilityProvider
          .overrideWith((ref) => Future.value(capability)),
    ],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      routerConfig: testRouter,
    ),
  );
}

void main() {
  group('LandingScreen', () {
    testWidgets('renders app title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Passport Reader'), findsOneWidget);
    });

    testWidgets('renders Get Started button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('renders all feature chips when NFC enabled', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('NFC Read'), findsOneWidget);
      expect(find.text('PA Verify'), findsOneWidget);
      expect(find.text('OCR Scan'), findsOneWidget);
    });

    testWidgets('renders only OCR chip when no chip reader', (tester) async {
      await tester.pumpWidget(
          _buildTestApp(capability: ChipReaderCapability.none));
      await tester.pumpAndSettle();

      expect(find.text('NFC Read'), findsNothing);
      expect(find.text('PA Verify'), findsNothing);
      expect(find.text('OCR Scan'), findsOneWidget);
    });

    testWidgets('renders language toggle button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('renders theme toggle button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // In light mode, shows dark_mode icon to switch
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('navigates to MRZ input on button tap', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('MRZ Input'), findsOneWidget);
    });

    testWidgets('renders Korean text when locale is ko', (tester) async {
      await tester.pumpWidget(_buildTestApp(locale: const Locale('ko')));
      await tester.pumpAndSettle();

      expect(find.text('시작하기'), findsOneWidget);
      expect(find.text('NFC 읽기'), findsOneWidget);
      expect(find.text('OCR 스캔'), findsOneWidget);
    });

    testWidgets('has passport, shield, and contactless icons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.byIcon(Icons.contactless), findsOneWidget);
    });

    testWidgets('renders copyright text', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copyright), findsOneWidget);
      expect(
        find.text('SmartCore Inc. All rights reserved.'),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark mode without error', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(theme: ThemeData.dark(useMaterial3: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Passport Reader'), findsOneWidget);
      // In dark mode, shows light_mode icon
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('has semantic label for screen', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label != null &&
              w.properties.label!.contains('Passport Reader'),
        ),
        findsWidgets,
      );
    });
  });
}
