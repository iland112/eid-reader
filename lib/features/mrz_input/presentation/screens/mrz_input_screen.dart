import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/device_capability_provider.dart';
import '../../../../app/locale_provider.dart';
import '../../../../app/theme_mode_provider.dart';
import '../../../../core/services/debug_log_service.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/entities/validation_error.dart';
import '../../domain/usecases/validate_mrz.dart';
import '../providers/mrz_input_provider.dart';
import '../widgets/viz_scan_result_card.dart';

class MrzInputScreen extends ConsumerStatefulWidget {
  const MrzInputScreen({super.key});

  @override
  ConsumerState<MrzInputScreen> createState() => _MrzInputScreenState();
}

class _MrzInputScreenState extends ConsumerState<MrzInputScreen>
    with SingleTickerProviderStateMixin {
  static final bool _isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  final _formKey = GlobalKey<FormState>();
  final _docNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _doeController = TextEditingController();
  final _validateMrz = ValidateMrz();

  late final AnimationController _animController;
  late final Animation<double> _instructionFade;
  late final Animation<Offset> _instructionSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _instructionFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _instructionSlide = Tween(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(_instructionFade);

    _formFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
    );
    _formSlide = Tween(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(_formFade);

    _buttonsFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _buttonsSlide = Tween(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(_buttonsFade);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
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
      text: context.l10n.shareLogText,
    );
  }

  void _onReadPassport() {
    if (!_formKey.currentState!.validate()) return;

    final mrzData = ref.read(mrzInputProvider).toMrzData();
    context.pushNamed('scan', extra: mrzData);
  }

  void _onViewOcrResult() {
    if (!_formKey.currentState!.validate()) return;

    final mrzData = ref.read(mrzInputProvider).toMrzData();
    final passportData = mrzData.toPassportData();
    context.pushNamed('passport-detail', extra: passportData);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mrzInputTitle),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: l10n.mrzInputTooltipShareLog,
              onPressed: _shareLogFile,
            ),
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: l10n.mrzInputTooltipSwitchLang,
            onPressed: () =>
                ref.read(localeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? l10n.mrzInputTooltipLightMode
                : l10n.mrzInputTooltipDarkMode,
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
              FadeTransition(
                opacity: _instructionFade,
                child: SlideTransition(
                  position: _instructionSlide,
                  child: Column(
                    children: [
                      // Capability banners
                      Builder(builder: (context) {
                        final capAsync =
                            ref.watch(chipReaderCapabilityProvider);
                        final capability = capAsync.valueOrNull;
                        if (capability == ChipReaderCapability.nfcDisabled) {
                          return _CapabilityBanner(
                            icon: Icons.nfc,
                            message: l10n.mrzInputNfcDisabledBanner,
                            color: Theme.of(context).colorScheme.error,
                          );
                        }
                        if (capability == ChipReaderCapability.none) {
                          return _CapabilityBanner(
                            icon: Icons.info_outline,
                            message: l10n.mrzInputOcrOnlyBanner,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      ref.watch(mrzInputProvider).cameraMrzData != null
                          ? VizScanResultCard(
                              mrzData:
                                  ref.watch(mrzInputProvider).cameraMrzData!)
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _isDesktop
                                    ? l10n.mrzInputInstructionDesktop
                                    : l10n.mrzInputInstructionMobile,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Form fields in a card
              FadeTransition(
                opacity: _formFade,
                child: SlideTransition(
                  position: _formSlide,
                  child: Card(
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
                decoration: InputDecoration(
                  labelText: l10n.labelDocumentNumber,
                  hintText: l10n.hintDocumentNumber,
                  prefixIcon: const Icon(Icons.badge),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(9),
                ],
                validator: (value) =>
                    _validationErrorToString(
                        _validateMrz.validateDocumentNumber(value ?? '')),
                onChanged: (value) =>
                    ref.read(mrzInputProvider.notifier).updateDocumentNumber(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                decoration: InputDecoration(
                  labelText: l10n.labelDateOfBirth,
                  hintText: l10n.hintDateOfBirth,
                  prefixIcon: const Icon(Icons.cake),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) =>
                    _validationErrorToString(
                        _validateMrz.validateDate(value ?? '')),
                onChanged: (value) =>
                    ref.read(mrzInputProvider.notifier).updateDateOfBirth(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doeController,
                decoration: InputDecoration(
                  labelText: l10n.labelDateOfExpiry,
                  hintText: l10n.hintDateOfExpiry,
                  prefixIcon: const Icon(Icons.event),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) =>
                    _validationErrorToString(
                        _validateMrz.validateDate(value ?? '')),
                onChanged: (value) =>
                    ref.read(mrzInputProvider.notifier).updateDateOfExpiry(value),
              ),
                    ],
                  ),
                ),
              ),
              ),
              ),
              const SizedBox(height: 24),
              // Capability-aware action buttons
              FadeTransition(
                opacity: _buttonsFade,
                child: SlideTransition(
                  position: _buttonsSlide,
                  child: Builder(builder: (context) {
                    final capAsync =
                        ref.watch(chipReaderCapabilityProvider);
                    final capability = capAsync.valueOrNull ??
                        ChipReaderCapability.none;
                    final hasChip = hasChipReader(capability);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Camera scan (mobile only)
                        if (Platform.isAndroid || Platform.isIOS) ...[
                          if (hasChip)
                            OutlinedButton.icon(
                              onPressed: _onScanMrz,
                              icon: const Icon(Icons.camera_alt),
                              label: Text(l10n.buttonScanViz),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _onScanMrz,
                              icon: const Icon(Icons.camera_alt),
                              label: Text(l10n.buttonScanViz),
                            ),
                          const SizedBox(height: 12),
                        ],
                        // Chip reader button (only when available)
                        if (hasChip)
                          ElevatedButton.icon(
                            onPressed: _onReadPassport,
                            icon: Icon(
                                _isDesktop ? Icons.usb : Icons.contactless),
                            label: Text(_isDesktop
                                ? l10n.buttonReadWithCardReader
                                : l10n.buttonScanPassport),
                          ),
                        // OCR-only: view passport info directly
                        if (!hasChip)
                          OutlinedButton.icon(
                            onPressed: _onViewOcrResult,
                            icon: const Icon(Icons.badge),
                            label:
                                Text(l10n.mrzInputButtonViewOcrResult),
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validationErrorToString(MrzValidationError? error) {
    if (error == null) return null;
    final l10n = context.l10n;
    return switch (error) {
      MrzValidationError.docNumberRequired =>
        l10n.validationDocNumberRequired,
      MrzValidationError.docNumberMaxLength =>
        l10n.validationDocNumberMaxLength,
      MrzValidationError.docNumberInvalidChars =>
        l10n.validationDocNumberInvalidChars,
      MrzValidationError.dateRequired => l10n.validationDateRequired,
      MrzValidationError.dateFormat => l10n.validationDateFormat,
      MrzValidationError.dateDigitsOnly => l10n.validationDateDigitsOnly,
      MrzValidationError.invalidMonth => l10n.validationInvalidMonth,
      MrzValidationError.invalidDay => l10n.validationInvalidDay,
    };
  }
}

class _CapabilityBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _CapabilityBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
