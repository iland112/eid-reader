import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/passport_reader/domain/entities/mrz_field_comparison.dart';
import 'package:eid_reader/features/passport_display/presentation/widgets/viz_verification_card.dart';

Widget _wrapInApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('VizVerificationCard MRZ field comparison', () {
    testWidgets('shows per-field results when fieldComparison provided',
        (tester) async {
      const comparison = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Document Number',
          ocrValue: 'L898902C',
          chipValue: 'L898902C',
          matches: true,
        ),
        MrzFieldMatch(
          fieldName: 'Surname',
          ocrValue: 'DOE',
          chipValue: 'SMITH',
          matches: false,
        ),
      ]);

      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: false,
          fieldComparison: comparison,
        ),
      ));

      // Summary row
      expect(find.textContaining('1/2 match'), findsOneWidget);

      // Per-field rows
      expect(find.text('Document Number'), findsOneWidget);
      expect(find.text('Surname'), findsOneWidget);
    });

    testWidgets('shows all-match summary when all fields match',
        (tester) async {
      const comparison = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Document Number',
          ocrValue: 'L898902C',
          chipValue: 'L898902C',
          matches: true,
        ),
        MrzFieldMatch(
          fieldName: 'Date of Birth',
          ocrValue: '690806',
          chipValue: '690806',
          matches: true,
        ),
        MrzFieldMatch(
          fieldName: 'Date of Expiry',
          ocrValue: '940623',
          chipValue: '940623',
          matches: true,
        ),
      ]);

      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: true,
          fieldComparison: comparison,
        ),
      ));

      expect(find.textContaining('3/3 match'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows mismatch values for non-matching fields',
        (tester) async {
      const comparison = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Nationality',
          ocrValue: 'UT0',
          chipValue: 'UTO',
          matches: false,
        ),
      ]);

      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: false,
          fieldComparison: comparison,
        ),
      ));

      // Should show OCR value != chip value
      expect(find.textContaining('UT0'), findsOneWidget);
      expect(find.textContaining('UTO'), findsOneWidget);
    });

    testWidgets('falls back to boolean display when no fieldComparison',
        (tester) async {
      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: true,
        ),
      ));

      expect(find.text('MRZ fields match chip data'), findsOneWidget);
    });

    testWidgets('shows mismatch text for boolean false', (tester) async {
      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: false,
        ),
      ));

      expect(find.text('MRZ fields mismatch'), findsOneWidget);
    });

    testWidgets('shows VIZ Verification title', (tester) async {
      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: true,
        ),
      ));

      expect(find.text('VIZ Verification'), findsOneWidget);
      expect(find.byIcon(Icons.compare), findsOneWidget);
    });

    testWidgets('shows check icons for matching fields', (tester) async {
      const comparison = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Document Number',
          ocrValue: 'AB123',
          chipValue: 'AB123',
          matches: true,
        ),
      ]);

      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: true,
          fieldComparison: comparison,
        ),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows close icons for mismatching fields', (tester) async {
      const comparison = MrzFieldComparisonResult(fieldMatches: [
        MrzFieldMatch(
          fieldName: 'Sex',
          ocrValue: 'M',
          chipValue: 'F',
          matches: false,
        ),
      ]);

      await tester.pumpWidget(_wrapInApp(
        const VizVerificationCard(
          mrzFieldsMatch: false,
          fieldComparison: comparison,
        ),
      ));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
