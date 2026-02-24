import 'package:flutter/material.dart';

import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/utils/mrz_utils.dart';
import '../../domain/entities/mrz_data.dart';

/// Card displaying VIZ scan results on the MrzInputScreen.
///
/// Shows face photo, personal info fields, and raw MRZ OCR lines
/// from the camera scan.
class VizScanResultCard extends StatelessWidget {
  final MrzData mrzData;

  const VizScanResultCard({super.key, required this.mrzData});

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
                Icon(Icons.document_scanner,
                    size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.vizScanResultTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Face photo + personal info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFacePhoto(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mrzData.surname != null)
                        _buildField(
                          context,
                          context.l10n.vizLabelName,
                          mrzData.givenNames != null &&
                                  mrzData.givenNames!.isNotEmpty
                              ? '${mrzData.givenNames} ${mrzData.surname}'
                              : mrzData.surname!,
                        ),
                      if (mrzData.documentType != null)
                        _buildField(
                            context, context.l10n.vizLabelDocType, mrzData.documentType!),
                      if (mrzData.issuingState != null)
                        _buildField(
                            context, context.l10n.vizLabelIssuingState, mrzData.issuingState!),
                      if (mrzData.nationality != null)
                        _buildField(
                            context, context.l10n.vizLabelNationality, mrzData.nationality!),
                      _buildField(
                          context, context.l10n.vizLabelDocNo, mrzData.documentNumber),
                      _buildField(
                        context,
                        context.l10n.vizLabelDob,
                        MrzUtils.formatDisplayDate(mrzData.dateOfBirth,
                            isDob: true),
                      ),
                      if (mrzData.sex != null && mrzData.sex!.isNotEmpty)
                        _buildField(context, context.l10n.vizLabelSex, mrzData.sex!),
                      _buildField(
                        context,
                        context.l10n.vizLabelExpiry,
                        MrzUtils.formatDisplayDate(mrzData.dateOfExpiry),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // MRZ OCR lines
            if (mrzData.mrzLine1 != null && mrzData.mrzLine2 != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${mrzData.mrzLine1}\n${mrzData.mrzLine2}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFacePhoto(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final faceBytes = mrzData.vizCaptureResult?.vizFaceImageBytes;

    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: faceBytes != null && faceBytes.isNotEmpty
          ? Image.memory(
              faceBytes,
              fit: BoxFit.cover,
              semanticLabel: context.l10n.semanticScannedFace,
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
    );
  }

  Widget _buildField(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
