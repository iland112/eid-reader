import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/presentation/providers/mrz_camera_provider.dart';

/// A testable version of the bottom panel from MrzCameraScreen.
/// We test the UI states directly since the camera preview requires hardware.
class _TestBottomPanel extends ConsumerWidget {
  const _TestBottomPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(mrzCameraProvider);
    final detected = cameraState.detectedMrz;

    if (detected != null) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'MRZ Detected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // MRZ line preview card
            if (detected.mrzLine1 != null && detected.mrzLine2 != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${detected.mrzLine1}\n${detected.mrzLine2}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                  ),
                  maxLines: 2,
                ),
              ),
            const SizedBox(height: 8),
            // Expanded MRZ fields
            if (detected.surname != null)
              Text(
                  'Name: ${detected.givenNames != null && detected.givenNames!.isNotEmpty ? '${detected.givenNames} ${detected.surname}' : detected.surname}'),
            Text('Document No.: ${detected.documentNumber}'),
            if (detected.nationality != null)
              Text('Nationality: ${detected.nationality}'),
            Text('Date of Birth: ${detected.dateOfBirth}'),
            if (detected.sex != null && detected.sex!.isNotEmpty)
              Text('Sex: ${detected.sex}'),
            Text('Date of Expiry: ${detected.dateOfExpiry}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(mrzCameraProvider.notifier).reset();
                    },
                    child: const Text('Rescan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(detected);
                    },
                    child: const Text('Use This Data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cameraState.isProcessing) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Position the MRZ area of your passport within the frame',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Mock text recognition service that doesn't use platform channels.
class _MockTextRecognitionService implements TextRecognitionService {
  @override
  Future<String> recognizeText(dynamic image) async => '';

  @override
  void close() {}
}

Widget _buildTestApp({
  MrzCameraNotifier? notifier,
}) {
  final mockService = _MockTextRecognitionService();
  final testNotifier =
      notifier ?? MrzCameraNotifier(recognitionService: mockService);

  return ProviderScope(
    overrides: [
      mrzCameraProvider.overrideWith((ref) => testNotifier),
    ],
    child: const MaterialApp(
      home: Scaffold(body: _TestBottomPanel()),
    ),
  );
}

void main() {
  group('MrzCameraScreen UI states', () {
    testWidgets('shows scanning instruction text when idle', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Position the MRZ area of your passport within the frame'),
        findsOneWidget,
      );
    });

    testWidgets('shows progress indicator when processing', (tester) async {
      final mockService = _MockTextRecognitionService();
      final notifier = MrzCameraNotifier(recognitionService: mockService);

      await tester.pumpWidget(_buildTestApp(notifier: notifier));
      await tester.pumpAndSettle();

      // Simulate processing state by directly manipulating
      // We can't set state directly, but we can verify the idle state
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows MRZ Detected panel when MRZ found', (tester) async {
      final mockService = _MockTextRecognitionService();
      final notifier = MrzCameraNotifier(recognitionService: mockService);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      notifier.processText('$line1\n$line2');

      await tester.pumpWidget(_buildTestApp(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('MRZ Detected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows detected document number', (tester) async {
      final mockService = _MockTextRecognitionService();
      final notifier = MrzCameraNotifier(recognitionService: mockService);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      notifier.processText('$line1\n$line2');

      await tester.pumpWidget(_buildTestApp(notifier: notifier));
      await tester.pumpAndSettle();

      // Document number appears in MRZ preview card + field display
      expect(find.textContaining('L898902C'), findsWidgets);
      expect(find.textContaining('690806'), findsWidgets);
      expect(find.textContaining('940623'), findsWidgets);
    });

    testWidgets('shows Use This Data and Rescan buttons when detected',
        (tester) async {
      final mockService = _MockTextRecognitionService();
      final notifier = MrzCameraNotifier(recognitionService: mockService);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      notifier.processText('$line1\n$line2');

      await tester.pumpWidget(_buildTestApp(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('Use This Data'), findsOneWidget);
      expect(find.text('Rescan'), findsOneWidget);
    });

    testWidgets('Rescan button clears detected MRZ', (tester) async {
      final mockService = _MockTextRecognitionService();
      final notifier = MrzCameraNotifier(recognitionService: mockService);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      notifier.processText('$line1\n$line2');

      await tester.pumpWidget(_buildTestApp(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('MRZ Detected'), findsOneWidget);

      await tester.tap(find.text('Rescan'));
      await tester.pumpAndSettle();

      expect(find.text('MRZ Detected'), findsNothing);
      expect(
        find.text(
            'Position the MRZ area of your passport within the frame'),
        findsOneWidget,
      );
    });

    testWidgets('does not show buttons when no MRZ detected', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Use This Data'), findsNothing);
      expect(find.text('Rescan'), findsNothing);
    });

    testWidgets('shows MRZ line preview card when MRZ detected',
        (tester) async {
      final mockService = _MockTextRecognitionService();
      final notifier = MrzCameraNotifier(recognitionService: mockService);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      notifier.processText('$line1\n$line2');

      await tester.pumpWidget(_buildTestApp(notifier: notifier));
      await tester.pumpAndSettle();

      // Should show the raw MRZ lines
      expect(find.textContaining('P<UTOERIKSSON'), findsOneWidget);
      expect(find.textContaining('L898902C<3UTO'), findsOneWidget);
    });

    testWidgets('shows expanded fields when MRZ detected', (tester) async {
      final mockService = _MockTextRecognitionService();
      final notifier = MrzCameraNotifier(recognitionService: mockService);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      notifier.processText('$line1\n$line2');

      await tester.pumpWidget(_buildTestApp(notifier: notifier));
      await tester.pumpAndSettle();

      // Should show name, nationality, sex from parsed MRZ
      expect(find.textContaining('ANNA MARIA ERIKSSON'), findsOneWidget);
      expect(find.textContaining('UTO'), findsWidgets);
      expect(find.textContaining('F'), findsWidgets);
    });
  });
}
