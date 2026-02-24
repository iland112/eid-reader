import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/utils/l10n_extension.dart';
import '../providers/passport_reader_provider.dart';

/// Animated card reader icon for Desktop PC/SC scanning screen.
///
/// Shows a smart card sliding into a reader with pulse animation
/// during active reading steps.
class CardReaderAnimation extends StatefulWidget {
  final ReadingStep step;

  const CardReaderAnimation({super.key, required this.step});

  @override
  State<CardReaderAnimation> createState() => _CardReaderAnimationState();
}

class _CardReaderAnimationState extends State<CardReaderAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(CardReaderAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.step == ReadingStep.done || widget.step == ReadingStep.error) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = widget.step != ReadingStep.idle &&
        widget.step != ReadingStep.error;
    final isDone = widget.step == ReadingStep.done;
    final isError = widget.step == ReadingStep.error;

    return Semantics(
      liveRegion: true,
      label: _semanticLabelForStep(context),
      child: SizedBox(
        width: 160,
        height: 160,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulseScale = isActive && !isDone
                ? 1.0 + sin(_controller.value * 2 * pi) * 0.03
                : 1.0;

            return Transform.scale(
              scale: pulseScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse rings (during active read)
                  if (isActive && !isDone)
                    _PulseRing(
                      progress: _controller.value,
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      size: 160,
                    ),
                  // Main icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? colorScheme.primaryContainer
                          : isError
                              ? colorScheme.errorContainer
                              : colorScheme.surfaceContainerHigh,
                    ),
                    child: Icon(
                      isDone
                          ? Icons.check_circle_outline
                          : isError
                              ? Icons.error_outline
                              : Icons.credit_card,
                      size: 48,
                      color: isDone
                          ? colorScheme.primary
                          : isError
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _semanticLabelForStep(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.step) {
      ReadingStep.idle => l10n.semanticCardReaderIdle,
      ReadingStep.connecting => l10n.semanticCardReaderConnecting,
      ReadingStep.authenticating ||
      ReadingStep.readingDg1 ||
      ReadingStep.readingDg2 ||
      ReadingStep.readingSod ||
      ReadingStep.verifyingPa ||
      ReadingStep.verifyingViz => l10n.semanticCardReaderReading,
      ReadingStep.done => l10n.semanticCardReaderDone,
      ReadingStep.error => l10n.semanticCardReaderError,
    };
  }
}

class _PulseRing extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;

  const _PulseRing({
    required this.progress,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + progress * 0.3;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: opacity * 0.5),
            width: 2,
          ),
        ),
      ),
    );
  }
}
