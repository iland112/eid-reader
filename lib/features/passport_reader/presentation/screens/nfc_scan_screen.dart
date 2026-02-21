import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';
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
        title: const Text('Scanning Passport'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            children: [
              // Step progress indicator
              ReadingStepIndicator(step: readerState.step),
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
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEBUG: ${readerState.debugError}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.greenAccent,
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
                      label: Text('Retry (${_retryCount + 1}/$_maxRetries)'),
                    ),
                  )
                else ...[
                  Text(
                    'Multiple attempts failed. Please re-check your passport details.',
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
                      label: const Text('Return to MRZ Input'),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_android, size: 32, color: colorScheme.primary),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward,
                    size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Icon(Icons.menu_book, size: 32, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Place phone flat on the passport data page',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Keep still until reading completes',
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
    final String message;
    switch (state.step) {
      case ReadingStep.idle:
        message = 'Preparing...';
      case ReadingStep.connecting:
        message = 'Waiting for passport...';
      case ReadingStep.authenticating:
        message = 'Authenticating...';
      case ReadingStep.readingDg1:
        message = 'Reading personal data...';
      case ReadingStep.readingDg2:
        message = 'Reading face image...';
      case ReadingStep.readingSod:
        message = 'Reading security data...';
      case ReadingStep.verifyingPa:
        message = 'Verifying document authenticity...';
      case ReadingStep.done:
        message = 'Scan complete!';
      case ReadingStep.error:
        message = state.errorMessage ?? 'An error occurred';
    }

    return Text(
      message,
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.center,
    );
  }
}
