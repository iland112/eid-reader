import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/passport_display/presentation/widgets/expiry_date_badge.dart';
import 'package:eid_reader/features/passport_display/presentation/widgets/face_comparison_badge.dart';
import 'package:eid_reader/features/passport_display/presentation/widgets/info_section_card.dart';
import 'package:eid_reader/features/passport_display/presentation/widgets/viz_verification_card.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/face_comparison_result.dart';

Widget _wrapInApp(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('ExpiryDateBadge semantics', () {
    testWidgets('has Semantics with excludeSemantics and label for valid date',
        (tester) async {
      // Use a date far in the future (2049 — ICAO: YY<50 → 20YY)
      await tester.pumpWidget(_wrapInApp(
        const ExpiryDateBadge(dateOfExpiry: '491231'),
      ));

      final semantics = tester.getSemantics(find.byType(ExpiryDateBadge));
      // The Semantics should have a label
      expect(semantics.label, isNotEmpty);
      expect(semantics.label, contains('Valid'));
    });

    testWidgets('has Semantics label for expired date', (tester) async {
      // Use a past date
      await tester.pumpWidget(_wrapInApp(
        const ExpiryDateBadge(dateOfExpiry: '200101'),
      ));

      final semantics = tester.getSemantics(find.byType(ExpiryDateBadge));
      expect(semantics.label, isNotEmpty);
      expect(semantics.label, contains('Expired'));
    });

    testWidgets('excludes child semantics so screen reader reads single label',
        (tester) async {
      await tester.pumpWidget(_wrapInApp(
        const ExpiryDateBadge(dateOfExpiry: '991231'),
      ));

      // There should be a Semantics node wrapping the badge
      expect(
        find.byWidgetPredicate(
            (w) => w is Semantics && w.excludeSemantics == true),
        findsOneWidget,
      );
    });
  });

  group('FaceComparisonBadge semantics', () {
    testWidgets('has Semantics with match label and percentage',
        (tester) async {
      const result = FaceComparisonResult(
        similarityScore: 0.85,
        threshold: 0.5,
      );

      await tester.pumpWidget(_wrapInApp(
        const FaceComparisonBadge(result: result),
      ));

      final semantics =
          tester.getSemantics(find.byType(FaceComparisonBadge));
      expect(semantics.label, isNotEmpty);
      expect(semantics.label, contains('Face Match'));
      expect(semantics.label, contains('85%'));
    });

    testWidgets('has Semantics with mismatch label for low score',
        (tester) async {
      const result = FaceComparisonResult(
        similarityScore: 0.1,
        threshold: 0.5,
      );

      await tester.pumpWidget(_wrapInApp(
        const FaceComparisonBadge(result: result),
      ));

      final semantics =
          tester.getSemantics(find.byType(FaceComparisonBadge));
      expect(semantics.label, contains('Mismatch'));
    });

    testWidgets('excludes child semantics', (tester) async {
      const result = FaceComparisonResult(
        similarityScore: 0.7,
        threshold: 0.5,
      );

      await tester.pumpWidget(_wrapInApp(
        const FaceComparisonBadge(result: result),
      ));

      expect(
        find.byWidgetPredicate(
            (w) => w is Semantics && w.excludeSemantics == true),
        findsOneWidget,
      );
    });
  });

  group('InfoSectionCard semantics', () {
    testWidgets('rows have MergeSemantics for label+value pairing',
        (tester) async {
      await tester.pumpWidget(_wrapInApp(
        const InfoSectionCard(
          title: 'Personal',
          icon: Icons.person,
          rows: [
            ('Name', 'John Doe'),
            ('Nationality', 'USA'),
          ],
        ),
      ));

      // Each row should be wrapped in MergeSemantics
      expect(find.byType(MergeSemantics), findsNWidgets(2));
    });

    testWidgets('title is visible', (tester) async {
      await tester.pumpWidget(_wrapInApp(
        const InfoSectionCard(
          title: 'Document Details',
          icon: Icons.badge,
          rows: [('Doc No.', 'AB123456')],
        ),
      ));

      expect(find.text('Document Details'), findsOneWidget);
    });
  });

  group('VizVerificationCard semantics', () {
    testWidgets('face images have semantic labels', (tester) async {
      const result = FaceComparisonResult(
        similarityScore: 0.8,
        threshold: 0.5,
      );

      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          faceComparison: result,
          mrzFieldsMatch: true,
        ),
      ));

      // Camera and Chip labels should be present
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Chip'), findsOneWidget);
    });

    testWidgets('title has VIZ Verification text', (tester) async {
      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: true,
        ),
      ));

      expect(find.text('VIZ Verification'), findsOneWidget);
    });
  });
}
