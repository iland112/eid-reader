import 'package:flutter/material.dart';

import '../providers/passport_reader_provider.dart';

/// Horizontal step indicator showing NFC reading phases.
///
/// Maps the detailed [ReadingStep] enum to user-visible phases:
/// Connect → Auth → Read → Verify → VIZ (optional)
///
/// The VIZ phase is only shown when [showVizStep] is true
/// (i.e., when a VIZ face was captured from the camera).
class ReadingStepIndicator extends StatelessWidget {
  final ReadingStep step;
  final bool showVizStep;

  const ReadingStepIndicator({
    super.key,
    required this.step,
    this.showVizStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final phase = _phaseFor(step);
    final isError = step == ReadingStep.error;

    final steps = <_StepConfig>[
      const _StepConfig('Connect', 0),
      const _StepConfig('Auth', 1),
      const _StepConfig('Read', 2),
      const _StepConfig('Verify', 3),
      if (showVizStep) const _StepConfig('VIZ', 4),
    ];

    final widgets = <Widget>[];
    for (int i = 0; i < steps.length; i++) {
      if (i > 0) {
        widgets.add(_StepConnector(completed: phase > steps[i - 1].phase));
      }
      widgets.add(_StepDot(
        label: steps[i].label,
        state: _dotState(steps[i].phase, phase, isError),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: widgets),
    );
  }

  /// Maps detailed ReadingStep to a 0–4 phase index.
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
        return 3;
      case ReadingStep.verifyingViz:
        return 4;
      case ReadingStep.done:
        return showVizStep ? 5 : 4;
      case ReadingStep.error:
        return -1; // handled separately
    }
  }

  _DotState _dotState(int dotPhase, int currentPhase, bool isError) {
    if (isError) {
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
    return 0;
  }
}

class _StepConfig {
  final String label;
  final int phase;
  const _StepConfig(this.label, this.phase);
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
