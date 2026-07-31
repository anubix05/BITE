import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated circular macro progress ring with overconsumption support.
class MacroRing extends StatefulWidget {
  const MacroRing({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
    this.size = 100,
    this.strokeWidth = 8,
  });

  final String label;
  final double value;
  final double goal;
  final String unit;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  State<MacroRing> createState() => _MacroRingState();
}

class _MacroRingState extends State<MacroRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(MacroRing old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isOver => widget.goal > 0 && widget.value > widget.goal;

  Color get _ringColor {
    if (widget.goal <= 0) return widget.color;
    if (_isOver) return const Color(0xFFF87171); // Over limit — coral red
    final ratio = widget.value / widget.goal;
    if (ratio >= 0.85) return const Color(0xFF34D399); // Near goal — green
    return widget.color;
  }

  @override
  Widget build(BuildContext context) {
    final baseProgress = widget.goal > 0
        ? (widget.value / widget.goal).clamp(0.0, 1.0)
        : 0.0;
    
    final overAmount = _isOver ? (widget.value - widget.goal) : 0.0;
    final overProgress = widget.goal > 0 && _isOver
        ? ((widget.value - widget.goal) / widget.goal).clamp(0.0, 1.0)
        : 0.0;

    final cs = Theme.of(context).colorScheme;
    final contentColor = cs.onPrimaryContainer;
    final overColor = const Color(0xFFF87171);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  progress: baseProgress * _animation.value,
                  overProgress: overProgress * _animation.value,
                  color: _ringColor,
                  overColor: overColor,
                  outlineColor: cs.primaryContainer,
                  strokeWidth: widget.strokeWidth,
                  trackColor: contentColor.withValues(alpha: 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.value.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _isOver ? overColor : contentColor,
                          height: 1,
                        ),
                  ),
                  Text(
                    _isOver
                        ? '+${overAmount.toStringAsFixed(0)}${widget.unit}'
                        : widget.unit,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: _isOver ? FontWeight.w700 : FontWeight.normal,
                          color: _isOver
                              ? overColor
                              : contentColor.withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isOver ? overColor : _ringColor,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.overProgress,
    required this.color,
    required this.overColor,
    required this.outlineColor,
    required this.strokeWidth,
    required this.trackColor,
  });

  final double progress;
  final double overProgress;
  final Color color;
  final Color overColor;
  final Color outlineColor;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }

    if (overProgress > 0) {
      final outlinePaint = Paint()
        ..color = outlineColor
        ..strokeWidth = strokeWidth + 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * overProgress,
        false,
        outlinePaint,
      );

      final overPaint = Paint()
        ..color = overColor
        ..strokeWidth = strokeWidth + 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * overProgress,
        false,
        overPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.overProgress != overProgress ||
      old.color != color ||
      old.overColor != overColor ||
      old.outlineColor != outlineColor;
}
