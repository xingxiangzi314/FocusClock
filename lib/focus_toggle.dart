import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui.dart';

/// The visual state follows the confirmed timer state, including external stops.
class FocusToggleButton extends StatefulWidget {
  final bool running;
  final String label;
  final VoidCallback? onTap;
  final double size;

  const FocusToggleButton({
    super.key,
    required this.running,
    required this.label,
    this.onTap,
    this.size = 58,
  });

  @override
  State<FocusToggleButton> createState() => _FocusToggleButtonState();
}

class _FocusToggleButtonState extends State<FocusToggleButton>
    with SingleTickerProviderStateMixin {
  // Unbounded values preserve the small overshoot when reversing mid-motion.
  late final AnimationController motion = AnimationController.unbounded(
    vsync: this,
    value: widget.running ? 1 : 0,
  );
  bool pressed = false;
  bool reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) motion.value = widget.running ? 1 : 0;
  }

  @override
  void didUpdateWidget(FocusToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      final target = widget.running ? 1.0 : 0.0;
      if (reduceMotion) {
        motion.value = target;
      } else {
        motion.animateTo(
          target,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
        );
      }
    }
    if (widget.onTap == null) pressed = false;
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      enabled: widget.onTap != null,
      child: Tooltip(
        message: widget.label,
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, _) {
              final progress = motion.value.clamp(0.0, 1.0);
              final shape = FocusToggleShape(
                motion.value,
                rotation: motion.value * math.pi / 4,
              );
              return AnimatedScale(
                scale: pressed && !reduceMotion ? .94 : 1,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 130),
                curve: Curves.easeOutBack,
                child: Transform.scale(
                  scale: reduceMotion
                      ? 1
                      : 1 + .065 * math.sin(math.pi * motion.value),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: p.blue,
                      shape: shape,
                      shadows: [
                        BoxShadow(
                          color: p.blue.withValues(alpha: .18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: shape,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: widget.onTap,
                        onHighlightChanged: (value) {
                          if (pressed != value) {
                            setState(() => pressed = value);
                          }
                        },
                        enableFeedback: false,
                        child: Center(
                          child: AnimatedIcon(
                            icon: AnimatedIcons.play_pause,
                            progress: AlwaysStoppedAnimation(progress),
                            size: widget.size * .43,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A smooth radial outline: circle at zero, rounded petals at one.
/// The footprint stays fixed so surrounding clock content never moves.
class FocusToggleShape extends ShapeBorder {
  final double progress;
  final double rotation;
  final int petals;
  const FocusToggleShape(this.progress, {this.rotation = 0, this.petals = 8});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final radius = rect.shortestSide / 2;
    final depth = .14 * progress.clamp(-.12, 1.12);
    final samples = petals * 24;
    for (var index = 0; index <= samples; index++) {
      final phase = index * math.pi * 2 / samples - math.pi / 2;
      final angle = phase + rotation;
      final r = radius * (1 - depth * (1 - math.cos(phase * petals)) / 2);
      final x = rect.center.dx + r * math.cos(angle);
      final y = rect.center.dy + r * math.sin(angle);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      FocusToggleShape(progress, rotation: rotation, petals: petals);
}

/// Decorative petals share the button's timing and rotate the opposite way.
/// This layer is painted before content and never takes taps or layout space.
class FocusPetalStage extends StatelessWidget {
  final bool running;
  final bool card;
  final Widget child;

  const FocusPetalStage({
    super.key,
    required this.running,
    required this.child,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final target = running ? 1.0 : 0.0;
    final p = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(MediaQuery.disableAnimationsOf(context)),
                tween: Tween(begin: target, end: target),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 360),
                curve: Curves.easeOutBack,
                builder: (context, progress, _) => CustomPaint(
                  painter: FocusPetalPainter(
                    progress: progress,
                    color: Color.lerp(
                      Color.lerp(p.card, p.well, .9),
                      Color.lerp(p.card, p.blue, p.dark ? .085 : .055),
                      progress.clamp(0.0, 1.0),
                    )!,
                    card: card,
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class FocusPetalPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool card;
  const FocusPetalPainter({
    required this.progress,
    required this.color,
    required this.card,
  });

  double get rotation => -progress * math.pi / 4;

  @override
  void paint(Canvas canvas, Size size) {
    // Keep the first backdrop's radius and horizontal anchor, shifting only up.
    // Its lower envelope meets the save button's bottom, above the card padding.
    final radius = card ? 58 * 2.4 : size.shortestSide * .875;
    final center = card
        ? Offset(size.width - 18 - 29, size.height - 14 - radius)
        : size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final outline = FocusToggleShape(
      1,
      rotation: rotation + math.pi / 16,
      petals: 8,
    ).getOuterPath(rect);
    canvas.drawPath(outline, Paint()..color = color);
  }

  @override
  bool shouldRepaint(FocusPetalPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      card != oldDelegate.card;
}
