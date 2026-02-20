import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/mrz_input/presentation/providers/mrz_camera_provider.dart';

/// Mock text recognition service for testing.
class MockTextRecognitionService implements TextRecognitionService {
  String _result = '';

  void mockResult(String text) {
    _result = text;
  }

  @override
  Future<String> recognizeText(InputImage image) async {
    return _result;
  }

  @override
  void close() {
    // No-op in tests
  }
}

void main() {
  group('MrzCameraState', () {
    test('has correct default values', () {
      const state = MrzCameraState();

      expect(state.isProcessing, false);
      expect(state.detectedMrz, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const mrz = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      const state = MrzCameraState(detectedMrz: mrz);

      final updated = state.copyWith(isProcessing: true);

      expect(updated.isProcessing, true);
      expect(updated.detectedMrz, mrz);
    });
  });

  group('MrzCameraNotifier', () {
    late MockTextRecognitionService mockService;

    setUp(() {
      mockService = MockTextRecognitionService();
    });

    test('initial state is default MrzCameraState', () {
      final notifier = MrzCameraNotifier(recognitionService: mockService);
      addTearDown(notifier.dispose);

      expect(notifier.state.isProcessing, false);
      expect(notifier.state.detectedMrz, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('processText detects valid MRZ', () {
      final notifier = MrzCameraNotifier(recognitionService: mockService);
      addTearDown(notifier.dispose);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';

      notifier.processText('$line1\n$line2');

      expect(notifier.state.detectedMrz, isNotNull);
      expect(notifier.state.detectedMrz!.documentNumber, 'L898902C');
      expect(notifier.state.detectedMrz!.dateOfBirth, '690806');
      expect(notifier.state.detectedMrz!.dateOfExpiry, '940623');
    });

    test('processText does not update state for invalid text', () {
      final notifier = MrzCameraNotifier(recognitionService: mockService);
      addTearDown(notifier.dispose);

      notifier.processText('random text with no MRZ');

      expect(notifier.state.detectedMrz, isNull);
    });

    test('reset clears detected MRZ', () {
      final notifier = MrzCameraNotifier(recognitionService: mockService);
      addTearDown(notifier.dispose);

      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      notifier.processText('$line1\n$line2');

      expect(notifier.state.detectedMrz, isNotNull);

      notifier.reset();

      expect(notifier.state.detectedMrz, isNull);
      expect(notifier.state.isProcessing, false);
    });

    test('provider type is correct', () {
      final container = ProviderContainer(
        overrides: [
          mrzCameraProvider.overrideWith(
            (ref) => MrzCameraNotifier(recognitionService: mockService),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(mrzCameraProvider);

      expect(state, isA<MrzCameraState>());
      expect(state.isProcessing, false);
    });

    test('processImage detects MRZ from recognized text', () async {
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      mockService.mockResult('$line1\n$line2');

      final notifier = MrzCameraNotifier(recognitionService: mockService);
      addTearDown(notifier.dispose);

      // Create a minimal InputImage for testing
      final image = InputImage.fromFilePath('/test/dummy.jpg');
      await notifier.processImage(image);

      expect(notifier.state.detectedMrz, isNotNull);
      expect(notifier.state.detectedMrz!.documentNumber, 'L898902C');
    });

    test('processImage returns empty state when no MRZ found', () async {
      mockService.mockResult('Some random text');

      final notifier = MrzCameraNotifier(recognitionService: mockService);
      addTearDown(notifier.dispose);

      final image = InputImage.fromFilePath('/test/dummy.jpg');
      await notifier.processImage(image);

      expect(notifier.state.detectedMrz, isNull);
      expect(notifier.state.isProcessing, false);
    });

    test('processImage skips when already detected', () async {
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C<3UTO6908061F9406236ZE184226B<<<<<14';
      mockService.mockResult('$line1\n$line2');

      final notifier = MrzCameraNotifier(recognitionService: mockService);
      addTearDown(notifier.dispose);

      // First detection
      final image = InputImage.fromFilePath('/test/dummy.jpg');
      await notifier.processImage(image);
      expect(notifier.state.detectedMrz, isNotNull);

      // Change mock to return nothing — but processImage should skip
      mockService.mockResult('nothing');
      await notifier.processImage(image);

      // Still has the first detection
      expect(notifier.state.detectedMrz, isNotNull);
      expect(notifier.state.detectedMrz!.documentNumber, 'L898902C');
    });
  });
}
