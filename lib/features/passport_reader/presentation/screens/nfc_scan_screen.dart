import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../providers/passport_reader_provider.dart';

class NfcScanScreen extends ConsumerStatefulWidget {
  final MrzData mrzData;

  const NfcScanScreen({super.key, required this.mrzData});

  @override
  ConsumerState<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends ConsumerState<NfcScanScreen> {
  @override
  void initState() {
    super.initState();
    // Start reading when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(passportReaderProvider.notifier).readPassport(widget.mrzData);
    });
  }

  @override
  void dispose() {
    // Reset state when leaving
    ref.read(passportReaderProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(passportReaderProvider);

    // Navigate to detail screen when done
    ref.listen(passportReaderProvider, (previous, next) {
      if (next.step == ReadingStep.done && next.data != null) {
        context.pushReplacementNamed('passport-detail', extra: next.data);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Passport'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIcon(readerState.step),
              const SizedBox(height: 32),
              _buildStatusText(readerState),
              const SizedBox(height: 16),
              if (readerState.step == ReadingStep.error) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ref
                        .read(passportReaderProvider.notifier)
                        .readPassport(widget.mrzData);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
              if (readerState.step != ReadingStep.error &&
                  readerState.step != ReadingStep.done)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ReadingStep step) {
    switch (step) {
      case ReadingStep.idle:
      case ReadingStep.connecting:
      case ReadingStep.authenticating:
      case ReadingStep.readingDg1:
      case ReadingStep.readingDg2:
        return Icon(
          Icons.nfc,
          size: 96,
          color: Theme.of(context).colorScheme.primary,
        );
      case ReadingStep.done:
        return Icon(
          Icons.check_circle,
          size: 96,
          color: Theme.of(context).colorScheme.primary,
        );
      case ReadingStep.error:
        return Icon(
          Icons.error,
          size: 96,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }

  Widget _buildStatusText(PassportReaderState state) {
    final String message;
    switch (state.step) {
      case ReadingStep.idle:
        message = 'Preparing...';
      case ReadingStep.connecting:
        message = 'Hold your phone against the back of the passport';
      case ReadingStep.authenticating:
        message = 'Authenticating...';
      case ReadingStep.readingDg1:
        message = 'Reading personal data...';
      case ReadingStep.readingDg2:
        message = 'Reading face image...';
      case ReadingStep.done:
        message = 'Reading complete!';
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
