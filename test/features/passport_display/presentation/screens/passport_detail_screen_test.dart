import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/core/platform/secure_screen_service.dart';
import 'package:eid_reader/features/passport_display/presentation/screens/passport_detail_screen.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/passport_data.dart';

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
  passiveAuthValid: false,
);

const _verifiedPassportData = PassportData(
  surname: 'SMITH',
  givenNames: 'JANE',
  documentNumber: 'X1234567',
  nationality: 'GBR',
  dateOfBirth: '850315',
  sex: 'F',
  dateOfExpiry: '350315',
  issuingState: 'GBR',
  documentType: 'P',
  authProtocol: 'PACE',
  passiveAuthValid: true,
  activeAuthValid: true,
);

/// Mock SecureScreenService that tracks calls.
class MockSecureScreenService implements SecureScreenService {
  int enableCount = 0;
  int disableCount = 0;

  @override
  Future<void> enableSecureMode() async {
    enableCount++;
  }

  @override
  Future<void> disableSecureMode() async {
    disableCount++;
  }
}

/// Builds a testable widget with provider overrides.
Widget _buildTestApp({
  required PassportData passportData,
  required MockSecureScreenService mockSecureService,
}) {
  return ProviderScope(
    overrides: [
      secureScreenServiceProvider.overrideWithValue(mockSecureService),
    ],
    child: MaterialApp(
      home: PassportDetailScreen(passportData: passportData),
    ),
  );
}

void main() {
  group('PassportDetailScreen', () {
    late MockSecureScreenService mockSecureService;

    setUp(() {
      mockSecureService = MockSecureScreenService();
    });

    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Passport Details'), findsOneWidget);
    });

    testWidgets('renders personal information section', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('JOHN DOE'), findsOneWidget);
      expect(find.text('USA'), findsWidgets); // nationality + issuingState
      expect(find.text('690806'), findsWidgets); // dateOfBirth + dateOfExpiry may overlap
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('renders document information section', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document Information'), findsOneWidget);
      expect(find.text('L898902C'), findsOneWidget);
      expect(find.text('940623'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('renders security status section', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Security Status'), findsOneWidget);
      expect(find.text('Not verified'), findsOneWidget);
      expect(find.text('N/A'), findsOneWidget); // activeAuthValid is null
      expect(find.text('BAC'), findsOneWidget);
    });

    testWidgets('shows Verification Pending badge when not verified',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verification Pending'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('shows Document Verified badge when verified', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _verifiedPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document Verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('shows verified passport data correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _verifiedPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JANE SMITH'), findsOneWidget);
      expect(find.text('PACE'), findsOneWidget);
      expect(find.text('Verified'), findsWidgets); // passive + active
    });

    testWidgets('shows person icon when no face image', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('shows Active Auth as Failed when false', (tester) async {
      const data = PassportData(
        surname: 'DOE',
        givenNames: 'JOHN',
        documentNumber: 'L898902C',
        nationality: 'USA',
        dateOfBirth: '690806',
        sex: 'M',
        dateOfExpiry: '940623',
        issuingState: 'USA',
        documentType: 'P',
        activeAuthValid: false,
      );

      await tester.pumpWidget(
        _buildTestApp(
          passportData: data,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('calls enableSecureMode on init', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(mockSecureService.enableCount, 1);
    });

    testWidgets('calls disableSecureMode and zeroes buffer on dispose',
        (tester) async {
      final faceBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final data = PassportData(
        surname: 'DOE',
        givenNames: 'JOHN',
        documentNumber: 'L898902C',
        nationality: 'USA',
        dateOfBirth: '690806',
        sex: 'M',
        dateOfExpiry: '940623',
        issuingState: 'USA',
        documentType: 'P',
        faceImageBytes: faceBytes,
      );

      // Use a navigatorKey so we can push a replacement within the same
      // ProviderScope, triggering dispose of PassportDetailScreen cleanly.
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureScreenServiceProvider.overrideWithValue(mockSecureService),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: PassportDetailScreen(passportData: data),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate away within the same ProviderScope to trigger dispose
      navKey.currentState!.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other')),
        ),
      );
      await tester.pumpAndSettle();

      // Verify secure mode was disabled
      expect(mockSecureService.disableCount, 1);

      // Verify buffer was zeroed
      expect(faceBytes.every((b) => b == 0), isTrue);
    });

    testWidgets('renders all section headers', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Document Information'), findsOneWidget);
      expect(find.text('Security Status'), findsOneWidget);
    });

    testWidgets('renders all field labels', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          passportData: _testPassportData,
          mockSecureService: mockSecureService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Nationality'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Sex'), findsOneWidget);
      expect(find.text('Document No.'), findsOneWidget);
      expect(find.text('Issuing State'), findsOneWidget);
      expect(find.text('Date of Expiry'), findsOneWidget);
      expect(find.text('Document Type'), findsOneWidget);
      expect(find.text('Passive Auth'), findsOneWidget);
      expect(find.text('Active Auth'), findsOneWidget);
      expect(find.text('Protocol'), findsOneWidget);
    });
  });
}
