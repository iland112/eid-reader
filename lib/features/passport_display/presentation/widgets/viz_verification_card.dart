import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/accessible_colors.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../passport_reader/domain/entities/face_comparison_result.dart';
import '../../../passport_reader/domain/entities/image_quality_metrics.dart';
import '../../../passport_reader/domain/entities/mrz_field_comparison.dart';
import 'face_comparison_badge.dart';

/// Card displaying VIZ-chip cross-verification results.
///
/// Shows:
/// - Side-by-side face comparison (VIZ camera vs chip DG2)
/// - Similarity score with match badge
/// - MRZ fields match status
/// - Image quality warnings
class VizVerificationCard extends StatelessWidget {
  final FaceComparisonResult? faceComparison;
  final bool? mrzFieldsMatch;
  final MrzFieldComparisonResult? fieldComparison;
  final ImageQualityMetrics? imageQuality;
  final Uint8List? vizFaceBytes;
  final Uint8List? chipFaceBytes;

  const VizVerificationCard({
    super.key,
    this.faceComparison,
    this.mrzFieldsMatch,
    this.fieldComparison,
    this.imageQuality,
    this.vizFaceBytes,
    this.chipFaceBytes,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.compare, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.vizVerificationTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Face comparison
            if (faceComparison != null) ...[
              _buildFaceComparison(context),
              const SizedBox(height: 12),
            ],

            // MRZ fields match (per-field or summary)
            if (fieldComparison != null)
              _buildMrzFieldsSection(context)
            else if (mrzFieldsMatch != null)
              _buildMrzFieldsRow(context),

            // Quality warnings
            if (imageQuality != null &&
                imageQuality!.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildQualityWarnings(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFaceComparison(BuildContext context) {
    return Column(
      children: [
        // Side-by-side faces
        Row(
          children: [
            Expanded(child: _buildFaceImage(context, vizFaceBytes, context.l10n.vizFaceLabelCamera, semanticLabel: context.l10n.semanticCameraFace)),
            const SizedBox(width: 12),
            Expanded(child: _buildFaceImage(context, chipFaceBytes, context.l10n.vizFaceLabelChip, semanticLabel: context.l10n.semanticChipFace)),
          ],
        ),
        const SizedBox(height: 8),
        // Match badge
        if (faceComparison != null)
          FaceComparisonBadge(result: faceComparison!),
      ],
    );
  }

  Widget _buildFaceImage(
    BuildContext context,
    Uint8List? imageBytes,
    String label, {
    String? semanticLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 80,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
            color: colorScheme.surfaceContainerHighest,
          ),
          clipBehavior: Clip.antiAlias,
          child: imageBytes != null && imageBytes.isNotEmpty
              ? Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  semanticLabel: semanticLabel,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person,
                    size: 40,
                    color: colorScheme.outlineVariant,
                  ),
                )
              : Icon(
                  Icons.person,
                  size: 40,
                  color: colorScheme.outlineVariant,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildMrzFieldsRow(BuildContext context) {
    final match = mrzFieldsMatch!;
    final brightness = Theme.of(context).brightness;
    final color = match
        ? AccessibleColors.success(brightness)
        : AccessibleColors.error(brightness);
    return Row(
      children: [
        Icon(
          match ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          match ? context.l10n.vizMrzFieldsMatch : context.l10n.vizMrzFieldsMismatch,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Widget _buildMrzFieldsSection(BuildContext context) {
    final comparison = fieldComparison!;
    final brightness = Theme.of(context).brightness;
    final summaryColor = comparison.allMatch
        ? AccessibleColors.success(brightness)
        : AccessibleColors.error(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Row(
          children: [
            Icon(
              comparison.allMatch ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: summaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.vizMrzFieldsSummary(comparison.matchCount.toString(), comparison.totalFields.toString()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: summaryColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Per-field rows
        for (final field in comparison.fieldMatches)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Row(
              children: [
                Icon(
                  field.matches ? Icons.check : Icons.close,
                  size: 12,
                  color: field.matches
                      ? AccessibleColors.success(brightness)
                      : AccessibleColors.error(brightness),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 110,
                  child: Text(
                    field.fieldName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (!field.matches) ...[
                  Expanded(
                    child: Text(
                      '${field.ocrValue ?? "?"} \u2260 ${field.chipValue}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AccessibleColors.error(brightness),
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQualityWarnings(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final qualityColor = switch (imageQuality!.qualityLevel) {
      ImageQualityLevel.good => AccessibleColors.success(brightness),
      ImageQualityLevel.acceptable => AccessibleColors.warning(brightness),
      ImageQualityLevel.poor => AccessibleColors.error(brightness),
      ImageQualityLevel.unusable => AccessibleColors.error(brightness),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_search, size: 14, color: qualityColor),
            const SizedBox(width: 4),
            Text(
              context.l10n.vizImageQualityLabel(imageQuality!.qualityLevel.name),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: qualityColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final issue in imageQuality!.issues)
          Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 2),
            child: Text(
              _imageQualityIssueToString(issue, context.l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }

  static String _imageQualityIssueToString(ImageQualityIssue issue, l10n) {
    return switch (issue) {
      ImageQualityIssue.blurry => l10n.qualityBlurry,
      ImageQualityIssue.severeGlare => l10n.qualitySevereGlare,
      ImageQualityIssue.moderateGlare => l10n.qualityModerateGlare,
      ImageQualityIssue.rainbowPattern => l10n.qualityRainbow,
      ImageQualityIssue.lowContrast => l10n.qualityLowContrast,
      ImageQualityIssue.decodeFailed => l10n.qualityFailedDecode,
      ImageQualityIssue.emptyImage => l10n.qualityEmptyImage,
    };
  }
}
