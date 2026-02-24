import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/l10n_extension.dart';
import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';
import '../../domain/entities/passport_read_error.dart';
import '../providers/passport_reader_provider.dart';
import '../widgets/card_reader_animation.dart';
import '../widgets/reading_step_indicator.dart';

/// Desktop PC/SC passport scanning screen.
///
/// Similar to [NfcScanScreen] but adapted for USB smart card readers:
/// - Uses [CardReaderAnimation] instead of NFC pulse
/// - Shows "Insert passport into reader" instead of phone positioning
/// - No wakelock or haptic feedback (Desktop doesn't need them)
class PcscScanScreen extends ConsumerStatefulWidget {
  final MrzData mrzData;

  const PcscScanScreen({super.key, required this.mrzData});

  @override
  ConsumerState<PcscScanScreen> createState() => _PcscScanScreenState();
}

class _PcscScanScreenState extends ConsumerState<PcscScanScreen> {
  PassportReaderNotifier? _notifier;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier = ref.read(passportReaderProvider.notifier);
      _notifier!.readPassport(widget.mrzData);
    });
  }

  @override
  void dispose() {
    final notifier = _notifier;
    if (notifier != null) {
      Future.microtask(() {
        if (notifier.mounted) notifier.reset();
      });
    }
    super.dispose();
  }

  void _scheduleNavigation(PassportData data) {
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

    ref.listen(passportReaderProvider, (previous, next) {
      if (next.step == ReadingStep.done && next.data != null) {
        _scheduleNavigation(next.data!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.pcscScanTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Column(
                children: [
                  ReadingStepIndicator(step: readerState.step),
                  const Spacer(),

                  CardReaderAnimation(step: readerState.step),
                  const SizedBox(height: 24),

                  _buildStatusText(readerState),
                  const SizedBox(height: 16),

                  if (readerState.step == ReadingStep.connecting ||
                      readerState.step == ReadingStep.idle)
                    _buildReaderGuide(context),

                  if (readerState.step == ReadingStep.error) ...[
                    if (readerState.debugError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
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
                        context.l10n.pcscScanMultipleFailures,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
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
        ),
      ),
    );
  }

  Widget _buildReaderGuide(BuildContext context) {
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
                  Icon(Icons.credit_card,
                      size: 32, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward,
                      size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Icon(Icons.usb, size: 32, color: colorScheme.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.pcscScanPositionTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.pcscScanPositionSubtitle,
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
        message = l10n.stepWaitingPcsc;
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
        message = l10n.stepReadComplete;
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
