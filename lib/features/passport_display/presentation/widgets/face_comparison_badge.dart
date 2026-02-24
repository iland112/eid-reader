import 'package:flutter/material.dart';

import '../../../../core/utils/accessible_colors.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../passport_reader/domain/entities/face_comparison_result.dart';

/// Badge displaying face matching status.
///
/// Colors: green (Match), red (Mismatch), orange (Low Confidence).
class FaceComparisonBadge extends StatelessWidget {
  final FaceComparisonResult result;

  const FaceComparisonBadge({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness = Theme.of(context).brightness;
    final (Color color, IconData icon, String label) = switch (result.confidence) {
      FaceComparisonConfidence.high => (AccessibleColors.success(brightness), Icons.check_circle, l10n.faceBadgeMatch),
      FaceComparisonConfidence.medium => (AccessibleColors.warning(brightness), Icons.info, l10n.faceBadgeLikelyMatch),
      FaceComparisonConfidence.low => (AccessibleColors.warning(brightness), Icons.warning, l10n.faceBadgeLowConfidence),
      FaceComparisonConfidence.unreliable => (AccessibleColors.error(brightness), Icons.cancel, l10n.faceBadgeMismatch),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      excludeSemantics: true,
      label:
          '$label ${(result.similarityScore * 100).toStringAsFixed(0)}%',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(result.similarityScore * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
