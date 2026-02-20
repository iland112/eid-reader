import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/secure_screen_service.dart';
import '../../../passport_reader/domain/entities/passport_data.dart';

class PassportDetailScreen extends ConsumerStatefulWidget {
  final PassportData passportData;

  const PassportDetailScreen({super.key, required this.passportData});

  @override
  ConsumerState<PassportDetailScreen> createState() =>
      _PassportDetailScreenState();
}

class _PassportDetailScreenState extends ConsumerState<PassportDetailScreen> {
  late final SecureScreenService _secureScreenService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _secureScreenService = ref.read(secureScreenServiceProvider);
      _secureScreenService.enableSecureMode();
    });
  }

  @override
  void dispose() {
    // Zero out biometric data buffer to prevent memory leaks of PII
    final faceBytes = widget.passportData.faceImageBytes;
    if (faceBytes != null) {
      faceBytes.fillRange(0, faceBytes.length, 0);
    }

    // Disable secure screen mode
    _secureScreenService.disableSecureMode();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Face image
            Center(
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: widget.passportData.faceImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          widget.passportData.faceImageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, size: 64),
                        ),
                      )
                    : const Icon(Icons.person, size: 64),
              ),
            ),
            const SizedBox(height: 24),

            // Security badge
            _buildSecurityBadge(context),
            const SizedBox(height: 24),

            // Personal information
            _buildSectionHeader(context, 'Personal Information'),
            _buildInfoRow('Name', widget.passportData.fullName),
            _buildInfoRow('Nationality', widget.passportData.nationality),
            _buildInfoRow(
                'Date of Birth', widget.passportData.dateOfBirth),
            _buildInfoRow('Sex', widget.passportData.sex),
            const SizedBox(height: 16),

            // Document information
            _buildSectionHeader(context, 'Document Information'),
            _buildInfoRow(
                'Document No.', widget.passportData.documentNumber),
            _buildInfoRow(
                'Issuing State', widget.passportData.issuingState),
            _buildInfoRow(
                'Date of Expiry', widget.passportData.dateOfExpiry),
            _buildInfoRow(
                'Document Type', widget.passportData.documentType),
            const SizedBox(height: 16),

            // Security status
            _buildSectionHeader(context, 'Security Status'),
            _buildInfoRow(
              'Passive Auth',
              widget.passportData.passiveAuthValid
                  ? 'Verified'
                  : 'Not verified',
            ),
            _buildInfoRow(
              'Active Auth',
              widget.passportData.activeAuthValid == null
                  ? 'N/A'
                  : widget.passportData.activeAuthValid!
                      ? 'Verified'
                      : 'Failed',
            ),
            _buildInfoRow('Protocol', widget.passportData.authProtocol),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadge(BuildContext context) {
    final isVerified = widget.passportData.passiveAuthValid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isVerified
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVerified ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.warning,
            color: isVerified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            isVerified ? 'Document Verified' : 'Verification Pending',
            style: TextStyle(
              color: isVerified ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
