import 'dart:typed_data';

import 'package:flutter/material.dart';

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
                  'VIZ Verification',
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
            Expanded(child: _buildFaceImage(context, vizFaceBytes, 'Camera')),
            const SizedBox(width: 12),
            Expanded(child: _buildFaceImage(context, chipFaceBytes, 'Chip')),
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
    String label,
  ) {
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
    final color = match ? Colors.green : Colors.red;
    return Row(
      children: [
        Icon(
          match ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          match ? 'MRZ fields match chip data' : 'MRZ fields mismatch',
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
    final summaryColor = comparison.allMatch ? Colors.green : Colors.red;

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
              'MRZ Fields: ${comparison.matchCount}/${comparison.totalFields} match',
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
                  color: field.matches ? Colors.green : Colors.red,
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
                            color: Colors.red,
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
    final qualityColor = switch (imageQuality!.qualityLevel) {
      ImageQualityLevel.good => Colors.green,
      ImageQualityLevel.acceptable => Colors.orange,
      ImageQualityLevel.poor => Colors.red,
      ImageQualityLevel.unusable => Colors.red,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_search, size: 14, color: qualityColor),
            const SizedBox(width: 4),
            Text(
              'Image Quality: ${imageQuality!.qualityLevel.name}',
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
              issue,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }
}
