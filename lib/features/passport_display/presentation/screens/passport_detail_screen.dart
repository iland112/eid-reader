import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../passport_reader/domain/entities/passport_data.dart';
import '../widgets/info_section_card.dart';
import '../widgets/passport_header_card.dart';

class PassportDetailScreen extends ConsumerStatefulWidget {
  final PassportData passportData;

  const PassportDetailScreen({super.key, required this.passportData});

  @override
  ConsumerState<PassportDetailScreen> createState() =>
      _PassportDetailScreenState();
}

class _PassportDetailScreenState extends ConsumerState<PassportDetailScreen> {
  @override
  void dispose() {
    // Zero out biometric data buffer to prevent memory leaks of PII
    final faceBytes = widget.passportData.faceImageBytes;
    if (faceBytes != null) {
      faceBytes.fillRange(0, faceBytes.length, 0);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.passportData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Passport-style header card
            PassportHeaderCard(passportData: data),
            const SizedBox(height: 12),

            // Security badge
            _buildSecurityBadge(context),
            const SizedBox(height: 12),

            // Personal information
            InfoSectionCard(
              title: 'Personal Information',
              icon: Icons.person,
              rows: [
                ('Name', data.fullName),
                ('Nationality', data.nationality),
                ('Date of Birth', data.dateOfBirth),
                ('Sex', data.sex),
              ],
            ),
            const SizedBox(height: 12),

            // Document information
            InfoSectionCard(
              title: 'Document Details',
              icon: Icons.badge,
              rows: [
                ('Document No.', data.documentNumber),
                ('Issuing State', data.issuingState),
                ('Date of Expiry', data.dateOfExpiry),
                ('Document Type', data.documentType),
              ],
            ),
            const SizedBox(height: 12),

            // Security status
            InfoSectionCard(
              title: 'Security Status',
              icon: Icons.security,
              rows: [
                (
                  'Passive Auth',
                  data.passiveAuthValid ? 'Verified' : 'Not verified',
                ),
                (
                  'Active Auth',
                  data.activeAuthValid == null
                      ? 'N/A'
                      : data.activeAuthValid!
                          ? 'Verified'
                          : 'Failed',
                ),
                ('Protocol', data.authProtocol),
              ],
            ),

            // PA Verification Details
            if (data.paVerificationResult != null) ...[
              const SizedBox(height: 12),
              _buildPaDetailsCard(context),
            ],

            // Scan Timing Debug
            if (data.debugTimings.isNotEmpty) ...[
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
        'Certificate Chain',
        pa.certificateChainValid == true ? 'Valid' : 'Invalid',
      ),
      if (pa.dscSubject != null) ('DSC Subject', pa.dscSubject!),
      if (pa.cscaSubject != null) ('CSCA Subject', pa.cscaSubject!),
      if (pa.crlStatus != null) ('CRL Status', pa.crlStatus!),
      (
        'SOD Signature',
        pa.sodSignatureValid == true ? 'Valid' : 'Invalid',
      ),
      if (pa.signatureAlgorithm != null) ('Algorithm', pa.signatureAlgorithm!),
      if (pa.totalGroups != null)
        ('Data Groups', '${pa.validGroups ?? 0}/${pa.totalGroups} valid'),
      if (pa.processingDurationMs != null)
        ('Verification Time', '${pa.processingDurationMs}ms'),
      if (pa.errorMessage != null) ('Error', pa.errorMessage!),
    ];

    return InfoSectionCard(
      title: 'PA Verification Details',
      icon: Icons.verified_user,
      rows: rows,
    );
  }

  Widget _buildTimingPanel() {
    final timings = widget.passportData.debugTimings;
    final total = timings.values.fold<int>(0, (a, b) => a + b);
    final labels = {
      'connect': 'Connect',
      'auth': 'BAC Auth',
      'dg1': 'DG1 (MRZ)',
      'dg2': 'DG2 (Face)',
      'sod': 'SOD',
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
                  'Scan Timing',
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
                    'Total',
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

  Widget _buildSecurityBadge(BuildContext context) {
    final isVerified = widget.passportData.passiveAuthValid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = isVerified ? Colors.green : Colors.orange;
    return Container(
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
            isVerified ? 'Document Verified' : 'Verification Pending',
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
