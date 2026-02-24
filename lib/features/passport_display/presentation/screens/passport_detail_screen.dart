import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/accessible_colors.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/utils/mrz_utils.dart';
import '../../../passport_reader/domain/entities/passport_data.dart';
import '../widgets/info_section_card.dart';
import '../widgets/passport_header_card.dart';
import '../widgets/viz_verification_card.dart';

class PassportDetailScreen extends ConsumerStatefulWidget {
  final PassportData passportData;

  const PassportDetailScreen({super.key, required this.passportData});

  @override
  ConsumerState<PassportDetailScreen> createState() =>
      _PassportDetailScreenState();
}

class _PassportDetailScreenState extends ConsumerState<PassportDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Create 6 staggered fade animations (0.1 offset each)
    _fadeAnims = List.generate(6, (i) {
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(
          i * 0.1,
          0.3 + i * 0.1,
          curve: Curves.easeOut,
        ),
      );
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    // Zero out biometric data buffers to prevent memory leaks of PII
    final faceBytes = widget.passportData.faceImageBytes;
    if (faceBytes != null) {
      faceBytes.fillRange(0, faceBytes.length, 0);
    }
    final vizFaceBytes = widget.passportData.vizFaceBytes;
    if (vizFaceBytes != null) {
      vizFaceBytes.fillRange(0, vizFaceBytes.length, 0);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.passportData;

    return Scaffold(
      appBar: AppBar(
        title: Text(data.isOcrOnly
            ? context.l10n.passportDetailOcrTitle
            : context.l10n.passportDetailTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Passport-style header card
            FadeTransition(
              opacity: _fadeAnims[0],
              child: PassportHeaderCard(passportData: data),
            ),
            const SizedBox(height: 12),

            // Security badge or OCR badge
            FadeTransition(
              opacity: _fadeAnims[1],
              child: data.isOcrOnly
                  ? _buildOcrBadge(context)
                  : _buildSecurityBadge(context),
            ),

            // VIZ verification (chip mode only)
            if (!data.isOcrOnly &&
                (data.faceComparisonResult != null ||
                    data.vizMrzFieldsMatch != null)) ...[
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _fadeAnims[2],
                child: VizVerificationCard(
                  faceComparison: data.faceComparisonResult,
                  mrzFieldsMatch: data.vizMrzFieldsMatch,
                  fieldComparison: data.vizMrzFieldComparison,
                  imageQuality: data.vizImageQuality,
                  vizFaceBytes: data.vizFaceBytes,
                  chipFaceBytes: data.faceImageBytes,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Personal information
            FadeTransition(
              opacity: _fadeAnims[3],
              child: InfoSectionCard(
                title: context.l10n.sectionPersonalInfo,
                icon: Icons.person,
                rows: [
                  (context.l10n.labelName, data.fullName),
                  (context.l10n.labelNationality, data.nationality),
                  (context.l10n.labelDateOfBirth, MrzUtils.formatDisplayDate(data.dateOfBirth, isDob: true)),
                  (context.l10n.labelSex, data.sex),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Document information
            FadeTransition(
              opacity: _fadeAnims[4],
              child: InfoSectionCard(
                title: context.l10n.sectionDocumentDetails,
                icon: Icons.badge,
                rows: [
                  (context.l10n.labelDocumentNo, data.documentNumber),
                  (context.l10n.labelIssuingState, data.issuingState),
                  (context.l10n.labelDateOfExpiry, MrzUtils.formatDisplayDate(data.dateOfExpiry)),
                  (context.l10n.labelDocumentType, data.documentType),
                ],
              ),
            ),

            // Security status (chip mode only)
            if (!data.isOcrOnly) ...[
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _fadeAnims[5],
                child: InfoSectionCard(
                  title: context.l10n.sectionSecurityStatus,
                  icon: Icons.security,
                  rows: [
                    (
                      context.l10n.labelPassiveAuth,
                      data.passiveAuthValid ? context.l10n.valueVerified : context.l10n.valueNotVerified,
                    ),
                    (
                      context.l10n.labelActiveAuth,
                      data.activeAuthValid == null
                          ? context.l10n.valueNA
                          : data.activeAuthValid!
                              ? context.l10n.valueVerified
                              : context.l10n.valueFailed,
                    ),
                    (context.l10n.labelProtocol, data.authProtocol),
                  ],
                ),
              ),
            ],

            // PA Verification Details (chip mode only)
            if (!data.isOcrOnly && data.paVerificationResult != null) ...[
              const SizedBox(height: 12),
              _buildPaDetailsCard(context),
            ],

            // Scan Timing Debug (chip mode only)
            if (!data.isOcrOnly && data.debugTimings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTimingPanel(),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaDetailsCard(BuildContext context) {
    final pa = widget.passportData.paVerificationResult!;
    final rows = <(String, String)>[
      (
        context.l10n.labelCertificateChain,
        pa.certificateChainValid == true ? context.l10n.labelValid : context.l10n.labelInvalid,
      ),
      if (pa.dscSubject != null) (context.l10n.labelDscSubject, pa.dscSubject!),
      if (pa.cscaSubject != null) (context.l10n.labelCscaSubject, pa.cscaSubject!),
      if (pa.crlStatus != null) (context.l10n.labelCrlStatus, pa.crlStatus!),
      (
        context.l10n.labelSodSignature,
        pa.sodSignatureValid == true ? context.l10n.labelValid : context.l10n.labelInvalid,
      ),
      if (pa.signatureAlgorithm != null) (context.l10n.labelAlgorithm, pa.signatureAlgorithm!),
      if (pa.totalGroups != null)
        (context.l10n.labelDataGroups, context.l10n.dataGroupsValue(pa.validGroups ?? 0, pa.totalGroups!)),
      if (pa.processingDurationMs != null)
        (context.l10n.labelVerificationTime, context.l10n.verificationTimeValue(pa.processingDurationMs!)),
      if (pa.errorMessage != null) (context.l10n.labelError, pa.errorMessage!),
    ];

    return InfoSectionCard(
      title: context.l10n.sectionPaVerification,
      icon: Icons.verified_user,
      rows: rows,
    );
  }

  Widget _buildTimingPanel() {
    final timings = widget.passportData.debugTimings;
    final total = timings.values.fold<int>(0, (a, b) => a + b);
    final labels = {
      'connect': context.l10n.timingConnect,
      'auth': context.l10n.timingBacAuth,
      'dg1': context.l10n.timingDg1,
      'dg2': context.l10n.timingDg2,
      'sod': context.l10n.timingSod,
    };
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  context.l10n.timingScanTiming,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in timings.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        labels[entry.key] ?? entry.key,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${(entry.value / 1000).toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Divider(color: colorScheme.outlineVariant, height: 8),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    context.l10n.timingTotal,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(total / 1000).toStringAsFixed(1)}s',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = AccessibleColors.info(Theme.of(context).brightness);
    return Semantics(
      excludeSemantics: true,
      label: context.l10n.semanticOcrBadge,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.document_scanner, color: badgeColor),
                const SizedBox(width: 8),
                Text(
                  context.l10n.badgeOcrOnly,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.badgeOcrOnlyDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: badgeColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadge(BuildContext context) {
    final isVerified = widget.passportData.passiveAuthValid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brightness = Theme.of(context).brightness;
    final badgeColor = isVerified
        ? AccessibleColors.success(brightness)
        : AccessibleColors.warning(brightness);
    return Semantics(
      excludeSemantics: true,
      label: isVerified
          ? context.l10n.semanticDocumentVerified
          : context.l10n.semanticVerificationPending,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVerified ? Icons.verified : Icons.warning,
              color: badgeColor,
            ),
            const SizedBox(width: 8),
            Text(
              isVerified
                  ? context.l10n.badgeDocumentVerified
                  : context.l10n.badgeVerificationPending,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
