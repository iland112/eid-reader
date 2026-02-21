import 'package:flutter/material.dart';

import '../../../../core/utils/mrz_utils.dart';

/// Color-coded badge showing passport expiry status.
///
/// - Green: valid (>1 year remaining)
/// - Orange: expiring soon (<1 year)
/// - Red: expired
class ExpiryDateBadge extends StatelessWidget {
  final String dateOfExpiry;

  const ExpiryDateBadge({super.key, required this.dateOfExpiry});

  @override
  Widget build(BuildContext context) {
    late final DateTime expiryDate;
    try {
      expiryDate = MrzUtils.parseYYMMDD(dateOfExpiry);
    } catch (_) {
      expiryDate = DateTime(2000);
    }
    final now = DateTime.now();
    final remaining = expiryDate.difference(now);

    final Color badgeColor;
    final String label;
    final IconData icon;

    if (remaining.isNegative) {
      badgeColor = Colors.red;
      label = 'Expired';
      icon = Icons.warning_amber;
    } else if (remaining.inDays < 365) {
      badgeColor = Colors.orange;
      label = 'Expiring soon';
      icon = Icons.schedule;
    } else {
      badgeColor = Colors.green;
      label = 'Valid';
      icon = Icons.check_circle_outline;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: badgeColor.withValues(alpha: isDark ? 0.7 : 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            '$label · ${MrzUtils.formatDisplayDate(dateOfExpiry)}',
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

}
