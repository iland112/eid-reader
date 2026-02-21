import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/utils/country_code_utils.dart';
import '../../../passport_reader/domain/entities/passport_data.dart';
import 'expiry_date_badge.dart';

/// Passport-style card showing photo, name, and key info.
class PassportHeaderCard extends StatelessWidget {
  final PassportData passportData;

  const PassportHeaderCard({super.key, required this.passportData});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.05),
              colorScheme.primary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Face image
            Hero(
              tag: 'passport-photo',
              child: Container(
                width: 100,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline),
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: passportData.faceImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          passportData.faceImageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, size: 48),
                        ),
                      )
                    : const Icon(Icons.person, size: 48),
              ),
            ),
            const SizedBox(width: 16),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passportData.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _NationalityBadge(
                          nationality: passportData.nationality),
                      const SizedBox(width: 8),
                      Text(
                        passportData.sex,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    passportData.documentNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ExpiryDateBadge(dateOfExpiry: passportData.dateOfExpiry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NationalityBadge extends StatelessWidget {
  final String nationality;

  const _NationalityBadge({required this.nationality});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final flagPath = CountryCodeUtils.flagAssetPath(nationality);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flagPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SvgPicture.asset(
                flagPath,
                width: 20,
                height: 14,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            nationality,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
