import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme_mode_provider.dart';
import '../../../../core/services/debug_log_service.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/usecases/validate_mrz.dart';
import '../providers/mrz_input_provider.dart';
import '../widgets/viz_scan_result_card.dart';

class MrzInputScreen extends ConsumerStatefulWidget {
  const MrzInputScreen({super.key});

  @override
  ConsumerState<MrzInputScreen> createState() => _MrzInputScreenState();
}

class _MrzInputScreenState extends ConsumerState<MrzInputScreen> {
  static final bool _isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
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

  Future<void> _shareLogFile() async {
    final path = DebugLogService.instance.logFilePath;
    if (path == null) return;
    await DebugLogService.instance.flush();
    await Share.shareXFiles(
      [XFile(path)],
      text: 'eID Reader debug log',
    );
  }

  void _onReadPassport() {
    if (!_formKey.currentState!.validate()) return;

    final mrzData = ref.read(mrzInputProvider).toMrzData();
    context.pushNamed('scan', extra: mrzData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eID Reader'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share debug log',
              onPressed: _shareLogFile,
            ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: () =>
                ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // VIZ scan result or instruction text
              if (ref.watch(mrzInputProvider).cameraMrzData != null)
                VizScanResultCard(
                    mrzData: ref.watch(mrzInputProvider).cameraMrzData!)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _isDesktop
                        ? 'Enter passport MRZ data to read the '
                          'e-Passport chip.'
                        : 'Scan the passport VIZ, or enter MRZ '
                          'data manually.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),

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
              // Camera scan only available on mobile (Android/iOS)
              if (Platform.isAndroid || Platform.isIOS) ...[
                OutlinedButton.icon(
                  onPressed: _onScanMrz,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan VIZ'),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _onReadPassport,
                icon: Icon(_isDesktop ? Icons.usb : Icons.contactless),
                label: Text(_isDesktop
                    ? 'Read with Card Reader'
                    : 'Scan Passport'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
