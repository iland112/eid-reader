import 'package:flutter/material.dart';

import '../../../passport_reader/domain/entities/face_comparison_result.dart';

/// Badge displaying face matching status.
///
/// Colors: green (Match), red (Mismatch), orange (Low Confidence).
class FaceComparisonBadge extends StatelessWidget {
  final FaceComparisonResult result;

  const FaceComparisonBadge({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (result.confidence) {
      FaceComparisonConfidence.high => (Colors.green, Icons.check_circle, 'Face Match'),
      FaceComparisonConfidence.medium => (Colors.orange, Icons.info, 'Likely Match'),
      FaceComparisonConfidence.low => (Colors.orange, Icons.warning, 'Low Confidence'),
      FaceComparisonConfidence.unreliable => (Colors.red, Icons.cancel, 'Mismatch'),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
    );
  }
}
