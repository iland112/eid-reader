import 'package:flutter/material.dart';

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
    final expiryDate = _parseYYMMDD(dateOfExpiry);
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
            label,
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

  /// Parses YYMMDD string to DateTime with 70-year pivot rule.
  DateTime _parseYYMMDD(String yymmdd) {
    if (yymmdd.length < 6) return DateTime(2000);
    final yy = int.tryParse(yymmdd.substring(0, 2)) ?? 0;
    final mm = int.tryParse(yymmdd.substring(2, 4)) ?? 1;
    final dd = int.tryParse(yymmdd.substring(4, 6)) ?? 1;
    final year = yy < 70 ? 2000 + yy : 1900 + yy;
    return DateTime(year, mm, dd);
  }
}
