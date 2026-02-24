import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/utils/l10n_extension.dart';
import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';
import '../../domain/entities/passport_read_error.dart';
import '../providers/passport_reader_provider.dart';
import '../widgets/nfc_pulse_animation.dart';
import '../widgets/reading_step_indicator.dart';

class NfcScanScreen extends ConsumerStatefulWidget {
  final MrzData mrzData;

  const NfcScanScreen({super.key, required this.mrzData});

  @override
  ConsumerState<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends ConsumerState<NfcScanScreen> {
  PassportReaderNotifier? _notifier;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // Keep screen on during NFC reading to prevent NFC power-off
    WakelockPlus.enable();
    // Start reading when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier = ref.read(passportReaderProvider.notifier);
      _notifier!.readPassport(widget.mrzData);
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    // Schedule reset after the current frame to avoid modifying provider
    // state during widget tree teardown (Riverpod restriction).
    final notifier = _notifier;
    if (notifier != null) {
      Future.microtask(() {
        if (notifier.mounted) notifier.reset();
      });
    }
    super.dispose();
  }

  void _scheduleNavigation(PassportData data) {
    // Brief delay to show success state before navigating
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.pushReplacementNamed('passport-detail', extra: data);
    });
  }

  void _retry() {
    setState(() => _retryCount++);
    ref.read(passportReaderProvider.notifier).readPassport(widget.mrzData);
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(passportReaderProvider);

    // Navigate to detail screen when done
    ref.listen(passportReaderProvider, (previous, next) {
      if (next.step == ReadingStep.done && next.data != null) {
        _scheduleNavigation(next.data!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.nfcScanTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            children: [
              // Step progress indicator
              ReadingStepIndicator(
                step: readerState.step,
                showVizStep: widget.mrzData.vizCaptureResult != null,
              ),
              const Spacer(),

              // Animated pulse
              NfcPulseAnimation(step: readerState.step),
              const SizedBox(height: 24),

              // Status message
              _buildStatusText(readerState),
              const SizedBox(height: 16),

              // Positioning guide (visible during connecting/idle)
              if (readerState.step == ReadingStep.connecting ||
                  readerState.step == ReadingStep.idle)
                _buildPositioningGuide(context),

              // Error section
              if (readerState.step == ReadingStep.error) ...[
                if (readerState.debugError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEBUG: ${readerState.debugError}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_retryCount < _maxRetries)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.nfcScanRetryButton(
                          '${_retryCount + 1}', '$_maxRetries')),
                    ),
                  )
                else ...[
                  Text(
                    context.l10n.nfcScanMultipleFailures,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.l10n.nfcScanReturnToMrz),
                    ),
                  ),
                ],
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositioningGuide(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_android,
                      size: 32, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward,
                      size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Icon(Icons.menu_book, size: 32, color: colorScheme.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.nfcScanPositionTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.nfcScanPositionSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText(PassportReaderState state) {
    final l10n = context.l10n;
    final String message;
    switch (state.step) {
      case ReadingStep.idle:
        message = l10n.stepPreparing;
      case ReadingStep.connecting:
        message = l10n.stepWaitingNfc;
      case ReadingStep.authenticating:
        message = l10n.stepAuthenticating;
      case ReadingStep.readingDg1:
        message = l10n.stepReadingPersonalData;
      case ReadingStep.readingDg2:
        message = l10n.stepReadingFaceImage;
      case ReadingStep.readingSod:
        message = l10n.stepReadingSecurityData;
      case ReadingStep.verifyingPa:
        message = l10n.stepVerifyingAuthenticity;
      case ReadingStep.verifyingViz:
        message = l10n.stepComparingFace;
      case ReadingStep.done:
        message = l10n.stepScanComplete;
      case ReadingStep.error:
        message = _passportReadErrorMessage(state.error, l10n);
    }

    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  static String _passportReadErrorMessage(
      PassportReadError? error, AppLocalizations l10n) {
    return switch (error) {
      PassportReadError.tagLost => l10n.errorTagLost,
      PassportReadError.authFailed => l10n.errorAuthFailed,
      PassportReadError.passportNotDetected => l10n.errorPassportNotDetected,
      PassportReadError.timeout => l10n.errorTimeout,
      PassportReadError.nfcError => l10n.errorNfc,
      PassportReadError.nfcNotSupported => l10n.errorNfcNotSupported,
      PassportReadError.nfcDisabled => l10n.errorNfcDisabled,
      PassportReadError.generic || null => l10n.errorGenericRead,
    };
  }
}
