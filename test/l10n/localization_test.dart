import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/app/locale_provider.dart';

void main() {
  group('AppLocalizations locale resolution', () {
    testWidgets('resolves Korean strings for ko locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(l10n.appTitle, '여권 리더');
      expect(l10n.mrzInputTitle, '여권 리더');
      expect(l10n.labelDocumentNumber, '여권번호');
      expect(l10n.buttonScanPassport, '여권 스캔');
      expect(l10n.expiryBadgeExpired, '만료됨');
    });

    testWidgets('resolves English strings for en locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(l10n.appTitle, 'Passport Reader');
      expect(l10n.mrzInputTitle, 'Passport Reader');
      expect(l10n.labelDocumentNumber, 'Document Number');
      expect(l10n.buttonScanPassport, 'Scan Passport');
      expect(l10n.expiryBadgeExpired, 'Expired');
    });

    testWidgets('falls back to Korean for unsupported locale',
        (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      // Should fall back to Korean (the preferred/template locale)
      expect(l10n.appTitle, '여권 리더');
    });
  });

  group('AppLocalizations parameterized strings', () {
    testWidgets('routeErrorPageNotFound includes URI', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(
        l10n.routeErrorPageNotFound('/unknown'),
        contains('/unknown'),
      );
    });

    testWidgets('nfcScanRetryButton formats current/max', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      final result = l10n.nfcScanRetryButton('2', '3');
      expect(result, contains('2'));
      expect(result, contains('3'));
    });

    testWidgets('vizMrzFieldsSummary formats match/total', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      final result = l10n.vizMrzFieldsSummary('5', '7');
      expect(result, contains('5'));
      expect(result, contains('7'));
    });

    testWidgets('dataGroupsValue formats valid/total', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      final result = l10n.dataGroupsValue('2', '3');
      expect(result, contains('2'));
      expect(result, contains('3'));
    });

    testWidgets('verificationTimeValue formats ms', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(l10n.verificationTimeValue('1234'), contains('1234'));
    });

    testWidgets('ko parameterized strings format correctly', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(
        l10n.routeErrorPageNotFound('/test'),
        contains('/test'),
      );
      expect(
        l10n.vizMrzFieldsSummary('3', '5'),
        contains('3'),
      );
      expect(
        l10n.semanticStepProgress('1', '5', '연결'),
        contains('1'),
      );
    });
  });

  group('Landing page localization keys', () {
    testWidgets('landingDescription resolves for en locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(l10n.landingDescription, contains('Securely read'));
      expect(l10n.landingButtonStart, 'Get Started');
      expect(l10n.landingFeatureNfc, 'NFC Read');
      expect(l10n.landingFeatureSecurity, 'PA Verify');
      expect(l10n.landingFeatureOcr, 'OCR Scan');
      expect(l10n.mrzInputButtonViewOcrResult, 'View Passport Info');
      expect(l10n.mrzInputNfcDisabledBanner, contains('NFC is disabled'));
      expect(l10n.mrzInputOcrOnlyBanner, contains('NFC not available'));
      expect(l10n.passportDetailOcrTitle, 'Passport Info (OCR)');
      expect(l10n.badgeOcrOnly, 'OCR Scan Only');
      expect(l10n.badgeOcrOnlyDescription, contains('MRZ only'));
      expect(l10n.semanticOcrBadge, contains('OCR scan only'));

      // PA extended fields (v2.1.4+)
      expect(l10n.labelExpirationStatus, 'Expiration');
      expect(l10n.labelValidAtSigningTime, 'Valid at Signing');
      expect(l10n.labelDscNonConformant, 'DSC Conformance');
      expect(l10n.dscNonConformantWarning, 'Non-Conformant');
      expect(l10n.paRateLimitError, contains('Server busy'));

      // CRL status descriptions
      expect(l10n.crlNotRevoked, 'Not Revoked');
      expect(l10n.crlRevoked, 'Revoked');
      expect(l10n.crlExpired, 'CRL Expired');
      expect(l10n.crlUnknown, 'Unknown');
    });

    testWidgets('landingDescription resolves for ko locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(l10n.landingDescription, contains('전자여권'));
      expect(l10n.landingButtonStart, '시작하기');
      expect(l10n.landingFeatureNfc, 'NFC 읽기');
      expect(l10n.landingFeatureOcr, 'OCR 스캔');
      expect(l10n.mrzInputButtonViewOcrResult, '여권 정보 보기');
      expect(l10n.passportDetailOcrTitle, '여권 정보 (OCR)');
      expect(l10n.badgeOcrOnly, 'OCR 스캔만');

      // PA extended fields (v2.1.4+)
      expect(l10n.labelExpirationStatus, '만료 상태');
      expect(l10n.labelDscNonConformant, 'DSC 준수 상태');
      expect(l10n.dscNonConformantWarning, '비준수');
      expect(l10n.paRateLimitError, contains('서버가'));

      // CRL status descriptions
      expect(l10n.crlNotRevoked, '폐지되지 않음');
      expect(l10n.crlRevoked, '폐지됨');
      expect(l10n.crlExpired, 'CRL 만료');
      expect(l10n.crlUnknown, '알 수 없음');
    });
  });

  group('LocaleNotifier', () {
    test('initial locale is Korean', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = container.read(localeProvider);
      expect(locale, const Locale('ko'));
    });

    test('setLocale changes locale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(localeProvider.notifier).setLocale(const Locale('en'));
      expect(container.read(localeProvider), const Locale('en'));
    });

    test('toggle switches from ko to en', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(localeProvider.notifier).toggle();
      expect(container.read(localeProvider), const Locale('en'));
    });

    test('toggle switches from en back to ko', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(localeProvider.notifier);
      notifier.toggle(); // ko → en
      notifier.toggle(); // en → ko
      expect(container.read(localeProvider), const Locale('ko'));
    });

    test('double toggle returns to original locale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(localeProvider.notifier);
      notifier.toggle();
      notifier.toggle();
      expect(container.read(localeProvider), const Locale('ko'));
    });

    test('setLocale to same locale does not error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(localeProvider.notifier).setLocale(const Locale('ko'));
      expect(container.read(localeProvider), const Locale('ko'));
    });
  });
}
