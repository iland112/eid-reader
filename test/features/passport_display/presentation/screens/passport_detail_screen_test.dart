import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/passport_display/presentation/screens/passport_detail_screen.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/pa_verification_result.dart';
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

/// Builds a testable widget.
Widget _buildTestApp({required PassportData passportData}) {
  return ProviderScope(
    child: MaterialApp(
      home: PassportDetailScreen(passportData: passportData),
    ),
  );
}

void main() {
  group('PassportDetailScreen', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('Passport Details'), findsOneWidget);
    });

    testWidgets('renders personal information section', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('JOHN DOE'), findsWidgets); // header card + info section
      expect(find.text('USA'), findsWidgets); // header badge + nationality + issuingState
      expect(find.text('06 Aug 1969'), findsWidgets); // dateOfBirth formatted
      expect(find.text('M'), findsWidgets); // sex in header + info
    });

    testWidgets('renders document information section', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document Details'), findsOneWidget);
      expect(find.text('L898902C'), findsWidgets); // header card + info
      expect(find.text('23 Jun 1994'), findsWidgets); // expiry formatted
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('renders security status section', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
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
        _buildTestApp(passportData: _testPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verification Pending'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('shows Document Verified badge when verified', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _verifiedPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document Verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('shows verified passport data correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _verifiedPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('JANE SMITH'), findsWidgets); // header + info
      expect(find.text('PACE'), findsOneWidget);
      expect(find.text('Verified'), findsWidgets); // passive + active
    });

    testWidgets('shows person icon when no face image', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsWidgets);
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
        _buildTestApp(passportData: data),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('zeroes face buffer on dispose', (tester) async {
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

      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navKey,
            home: PassportDetailScreen(passportData: data),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate away to trigger dispose
      navKey.currentState!.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other')),
        ),
      );
      await tester.pumpAndSettle();

      // Verify buffer was zeroed
      expect(faceBytes.every((b) => b == 0), isTrue);
    });

    testWidgets('renders all section headers', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Document Details'), findsOneWidget);
      expect(find.text('Security Status'), findsOneWidget);
    });

    testWidgets('renders all field labels', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
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

    testWidgets('does not show PA details section when no PA result',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(passportData: _testPassportData),
      );
      await tester.pumpAndSettle();

      expect(find.text('PA Verification Details'), findsNothing);
    });

    testWidgets('shows PA Verification Details section when PA result present',
        (tester) async {
      const paResult = PaVerificationResult(
        status: 'VALID',
        verificationId: 'uuid-123',
        processingDurationMs: 245,
        certificateChainValid: true,
        dscSubject: '/C=KR/CN=DSC 01',
        cscaSubject: '/C=KR/CN=CSCA KR',
        crlStatus: 'NOT_REVOKED',
        sodSignatureValid: true,
        signatureAlgorithm: 'SHA256withRSA',
        totalGroups: 2,
        validGroups: 2,
        invalidGroups: 0,
      );
      final dataWithPa = _testPassportData.copyWith(
        passiveAuthValid: true,
        paVerificationResult: paResult,
      );

      await tester.pumpWidget(
        _buildTestApp(passportData: dataWithPa),
      );
      await tester.pumpAndSettle();

      expect(find.text('PA Verification Details'), findsOneWidget);
      expect(find.text('Certificate Chain'), findsOneWidget);
      expect(find.text('SOD Signature'), findsOneWidget);
      expect(find.text('Data Groups'), findsOneWidget);
      expect(find.text('Verification Time'), findsOneWidget);
    });

    testWidgets('shows PA certificate chain details', (tester) async {
      const paResult = PaVerificationResult(
        status: 'VALID',
        certificateChainValid: true,
        dscSubject: '/C=KR/CN=DSC 01',
        cscaSubject: '/C=KR/CN=CSCA KR',
        crlStatus: 'NOT_REVOKED',
        sodSignatureValid: true,
        signatureAlgorithm: 'SHA256withRSA',
        totalGroups: 2,
        validGroups: 2,
        invalidGroups: 0,
        processingDurationMs: 200,
      );
      final dataWithPa = _testPassportData.copyWith(
        passiveAuthValid: true,
        paVerificationResult: paResult,
      );

      await tester.pumpWidget(
        _buildTestApp(passportData: dataWithPa),
      );
      await tester.pumpAndSettle();

      // Certificate chain
      expect(find.text('Valid'), findsNWidgets(2)); // cert chain + SOD sig
      expect(find.text('/C=KR/CN=DSC 01'), findsOneWidget);
      expect(find.text('/C=KR/CN=CSCA KR'), findsOneWidget);
      expect(find.text('NOT_REVOKED'), findsOneWidget);

      // SOD signature
      expect(find.text('SHA256withRSA'), findsOneWidget);

      // Data groups
      expect(find.text('2/2 valid'), findsOneWidget);

      // Processing time
      expect(find.text('200ms'), findsOneWidget);
    });

    testWidgets('shows PA error message when verification has error',
        (tester) async {
      final paResult = PaVerificationResult.error('SOD parsing failed');
      final dataWithPa = _testPassportData.copyWith(
        paVerificationResult: paResult,
      );

      await tester.pumpWidget(
        _buildTestApp(passportData: dataWithPa),
      );
      await tester.pumpAndSettle();

      expect(find.text('PA Verification Details'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('SOD parsing failed'), findsOneWidget);
    });
  });
}
