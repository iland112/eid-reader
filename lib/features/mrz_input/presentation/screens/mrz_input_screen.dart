import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/mrz_data.dart';
import '../../domain/usecases/validate_mrz.dart';
import '../providers/mrz_input_provider.dart';

class MrzInputScreen extends ConsumerStatefulWidget {
  const MrzInputScreen({super.key});

  @override
  ConsumerState<MrzInputScreen> createState() => _MrzInputScreenState();
}

class _MrzInputScreenState extends ConsumerState<MrzInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _doeController = TextEditingController();
  final _validateMrz = ValidateMrz();

  @override
  void dispose() {
    _docNumberController.dispose();
    _dobController.dispose();
    _doeController.dispose();
    super.dispose();
  }

  Future<void> _onScanMrz() async {
    final result = await context.pushNamed<MrzData>('mrz-camera');
    if (result != null && mounted) {
      ref.read(mrzInputProvider.notifier).setFromMrz(result);
      _docNumberController.text = result.documentNumber;
      _dobController.text = result.dateOfBirth;
      _doeController.text = result.dateOfExpiry;
    }
  }

  void _onReadPassport() {
    if (!_formKey.currentState!.validate()) return;

    final mrzData = ref.read(mrzInputProvider).toMrzData();
    context.pushNamed('nfc-scan', extra: mrzData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eID Reader'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instruction card
              Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter Passport MRZ Data',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the three data fields from your passport\'s '
                        'machine-readable zone, or scan them with your camera.',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Form fields in a card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
              TextFormField(
                controller: _docNumberController,
                decoration: const InputDecoration(
                  labelText: 'Document Number',
                  hintText: 'e.g. M12345678',
                  prefixIcon: Icon(Icons.badge),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(9),
                ],
                validator: (value) =>
                    _validateMrz.validateDocumentNumber(value ?? ''),
                onChanged: (value) =>
                    ref.read(mrzInputProvider.notifier).updateDocumentNumber(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'YYMMDD (e.g. 900115)',
                  prefixIcon: Icon(Icons.cake),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) =>
                    _validateMrz.validateDate(value ?? '', fieldName: 'Date of birth'),
                onChanged: (value) =>
                    ref.read(mrzInputProvider.notifier).updateDateOfBirth(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doeController,
                decoration: const InputDecoration(
                  labelText: 'Date of Expiry',
                  hintText: 'YYMMDD (e.g. 300115)',
                  prefixIcon: Icon(Icons.event),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) =>
                    _validateMrz.validateDate(value ?? '', fieldName: 'Date of expiry'),
                onChanged: (value) =>
                    ref.read(mrzInputProvider.notifier).updateDateOfExpiry(value),
              ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _onScanMrz,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan MRZ'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _onReadPassport,
                icon: const Icon(Icons.contactless),
                label: const Text('Scan Passport'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
