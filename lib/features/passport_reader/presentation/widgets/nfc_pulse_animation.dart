import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/l10n_extension.dart';
import '../providers/passport_reader_provider.dart';

/// Animated NFC pulse effect with concentric ripple rings.
///
/// Replaces the static NFC icon with a radar-like pulsing animation
/// that adapts to the current [ReadingStep].
class NfcPulseAnimation extends StatefulWidget {
  final ReadingStep step;

  const NfcPulseAnimation({super.key, required this.step});

  @override
  State<NfcPulseAnimation> createState() => _NfcPulseAnimationState();
}

class _NfcPulseAnimationState extends State<NfcPulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationForStep(widget.step),
    );
    _startAnimationForStep(widget.step);
  }

  @override
  void didUpdateWidget(NfcPulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _controller.duration = _durationForStep(widget.step);
      _startAnimationForStep(widget.step);
    }
  }

  Duration _durationForStep(ReadingStep step) {
    switch (step) {
      case ReadingStep.idle:
      case ReadingStep.connecting:
        return const Duration(milliseconds: 2000);
      case ReadingStep.authenticating:
      case ReadingStep.readingDg1:
      case ReadingStep.readingDg2:
      case ReadingStep.readingSod:
        return const Duration(milliseconds: 1200);
      case ReadingStep.verifyingPa:
      case ReadingStep.verifyingViz:
      case ReadingStep.done:
      case ReadingStep.error:
        return const Duration(milliseconds: 2000);
    }
  }

  void _startAnimationForStep(ReadingStep step) {
    switch (step) {
      case ReadingStep.idle:
      case ReadingStep.connecting:
      case ReadingStep.authenticating:
      case ReadingStep.readingDg1:
      case ReadingStep.readingDg2:
      case ReadingStep.readingSod:
      case ReadingStep.verifyingPa:
      case ReadingStep.verifyingViz:
        _controller.repeat();
      case ReadingStep.done:
        _controller.stop();
        _controller.value = 0;
      case ReadingStep.error:
        _controller.stop();
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
    final isError = widget.step == ReadingStep.error;
    final isDone = widget.step == ReadingStep.done;

    final ringColor = isError ? colorScheme.error : colorScheme.primary;

    return Semantics(
      liveRegion: true,
      label: _semanticLabelForStep(context),
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple rings
            if (!isDone)
              CustomPaint(
                size: const Size(200, 200),
                painter: _RipplePainter(
                  animation: _controller,
                  color: ringColor,
                  ringCount: 3,
                ),
              ),

            // Center circle with icon
            _buildCenterIcon(colorScheme, isError, isDone),
          ],
        ),
      ),
    );
  }

  String _semanticLabelForStep(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.step) {
      ReadingStep.idle => l10n.semanticNfcIdle,
      ReadingStep.connecting => l10n.semanticNfcConnecting,
      ReadingStep.authenticating => l10n.semanticNfcAuthenticating,
      ReadingStep.readingDg1 => l10n.semanticNfcReadingPersonal,
      ReadingStep.readingDg2 => l10n.semanticNfcReadingFace,
      ReadingStep.readingSod => l10n.semanticNfcReadingSecurity,
      ReadingStep.verifyingPa => l10n.semanticNfcVerifyingPa,
      ReadingStep.verifyingViz => l10n.semanticNfcVerifyingViz,
      ReadingStep.done => l10n.semanticNfcDone,
      ReadingStep.error => l10n.semanticNfcError,
    };
  }

  Widget _buildCenterIcon(ColorScheme colorScheme, bool isError, bool isDone) {
    final bgColor = isError
        ? colorScheme.error
        : isDone
            ? colorScheme.tertiary
            : colorScheme.primary;

    final IconData icon;
    switch (widget.step) {
      case ReadingStep.idle:
      case ReadingStep.connecting:
        icon = Icons.contactless;
      case ReadingStep.authenticating:
      case ReadingStep.readingDg1:
      case ReadingStep.readingDg2:
      case ReadingStep.readingSod:
        icon = Icons.contactless;
      case ReadingStep.verifyingPa:
      case ReadingStep.verifyingViz:
        icon = Icons.verified_user;
      case ReadingStep.done:
        icon = Icons.check_circle;
      case ReadingStep.error:
        icon = Icons.close;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isDone ? 80 : 72,
      height: isDone ? 80 : 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: isDone ? 44 : 36,
        color: isError
            ? colorScheme.onError
            : isDone
                ? colorScheme.onTertiary
                : colorScheme.onPrimary,
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final int ringCount;

  _RipplePainter({
    required this.animation,
    required this.color,
    required this.ringCount,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    for (var i = 0; i < ringCount; i++) {
      final phaseShift = i / ringCount;
      final t = (animation.value + phaseShift) % 1.0;

      final radius = 36.0 + (maxRadius - 36.0) * t;
      final opacity = (1.0 - t) * 0.35;
      final strokeWidth = 2.5 * (1.0 - t) + 0.5;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      color != oldDelegate.color || ringCount != oldDelegate.ringCount;
}
