import 'package:flutter/material.dart';

import '../providers/passport_reader_provider.dart';

/// Horizontal step indicator showing 4 NFC reading phases.
///
/// Maps the detailed [ReadingStep] enum to 4 user-visible phases:
/// Connect → Auth → Read → Verify
class ReadingStepIndicator extends StatelessWidget {
  final ReadingStep step;

  const ReadingStepIndicator({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final phase = _phaseFor(step);
    final isError = step == ReadingStep.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _StepDot(
            label: 'Connect',
            state: _dotState(0, phase, isError),
          ),
          _StepConnector(completed: phase > 0),
          _StepDot(
            label: 'Auth',
            state: _dotState(1, phase, isError),
          ),
          _StepConnector(completed: phase > 1),
          _StepDot(
            label: 'Read',
            state: _dotState(2, phase, isError),
          ),
          _StepConnector(completed: phase > 2),
          _StepDot(
            label: 'Verify',
            state: _dotState(3, phase, isError),
          ),
        ],
      ),
    );
  }

  /// Maps detailed ReadingStep to a 0–3 phase index.
  int _phaseFor(ReadingStep step) {
    switch (step) {
      case ReadingStep.idle:
      case ReadingStep.connecting:
        return 0;
      case ReadingStep.authenticating:
        return 1;
      case ReadingStep.readingDg1:
      case ReadingStep.readingDg2:
      case ReadingStep.readingSod:
        return 2;
      case ReadingStep.verifyingPa:
      case ReadingStep.done:
        return 3;
      case ReadingStep.error:
        return -1; // handled separately
    }
  }

  _DotState _dotState(int dotPhase, int currentPhase, bool isError) {
    if (isError) {
      // On error, show the last active phase as error, previous as completed
      // We use currentPhase = -1 for error, but we need to know which phase
      // the error occurred in. We approximate by checking the step.
      final errorPhase = _errorPhase();
      if (dotPhase < errorPhase) return _DotState.completed;
      if (dotPhase == errorPhase) return _DotState.error;
      return _DotState.pending;
    }
    if (dotPhase < currentPhase) return _DotState.completed;
    if (dotPhase == currentPhase) return _DotState.active;
    return _DotState.pending;
  }

  int _errorPhase() {
    // When error occurs, the step is still at error but we can infer
    // which phase it was in from the state. Default to 0 (connect).
    return 0;
  }
}

enum _DotState { pending, active, completed, error }

class _StepDot extends StatelessWidget {
  final String label;
  final _DotState state;

  const _StepDot({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color bgColor;
    final Color borderColor;
    final Widget? child;

    switch (state) {
      case _DotState.completed:
        bgColor = colorScheme.primary;
        borderColor = colorScheme.primary;
        child = Icon(Icons.check, size: 14, color: colorScheme.onPrimary);
      case _DotState.active:
        bgColor = Colors.transparent;
        borderColor = colorScheme.primary;
        child = Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
        );
      case _DotState.error:
        bgColor = colorScheme.error;
        borderColor = colorScheme.error;
        child = Icon(Icons.close, size: 14, color: colorScheme.onError);
      case _DotState.pending:
        bgColor = Colors.transparent;
        borderColor = colorScheme.outlineVariant;
        child = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: child != null ? Center(child: child) : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: state == _DotState.pending
                    ? colorScheme.outlineVariant
                    : state == _DotState.error
                        ? colorScheme.error
                        : colorScheme.onSurface,
                fontWeight:
                    state == _DotState.active ? FontWeight.bold : null,
              ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool completed;

  const _StepConnector({required this.completed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          decoration: BoxDecoration(
            color: completed
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
