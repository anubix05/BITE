import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android 17 / Material 3 Expressive thick-pill slider widget.
class ExpressiveSlider extends StatefulWidget {
  const ExpressiveSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.height = 44,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.icon,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final IconData? icon;

  @override
  State<ExpressiveSlider> createState() => _ExpressiveSliderState();
}

class _ExpressiveSliderState extends State<ExpressiveSlider> {
  bool _isDragging = false;

  void _updateValue(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    double trackRadius = widget.height / 2;
    double usableWidth =
        (totalWidth - widget.height).clamp(1.0, double.infinity);
    double rawFraction = ((localX - trackRadius) / usableWidth).clamp(0.0, 1.0);
    double range = widget.max - widget.min;
    double calcValue;

    if (widget.divisions != null && widget.divisions! > 0) {
      double stepFraction = 1.0 / widget.divisions!;
      int steps = (rawFraction / stepFraction).round();
      calcValue = widget.min + (steps * stepFraction * range);
    } else {
      calcValue = widget.min + (rawFraction * range);
    }

    calcValue = calcValue.clamp(widget.min, widget.max);
    if ((calcValue - widget.value).abs() > 0.001) {
      HapticFeedback.selectionClick();
      widget.onChanged(calcValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeBg = widget.activeColor ?? cs.primary;
    final inactiveBg = widget.inactiveColor ?? cs.surfaceContainerHighest;
    final handleColor = widget.thumbColor ?? cs.onPrimary;

    final range = widget.max - widget.min;
    final currentFraction = range > 0
        ? ((widget.value - widget.min) / range).clamp(0.0, 1.0)
        : 0.0;

    final currentHeight = _isDragging ? widget.height + 4 : widget.height;
    final trackRadius = currentHeight / 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: currentHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final usableWidth =
              (width - currentHeight).clamp(0.0, double.infinity);
          final fillWidth = currentHeight + (usableWidth * currentFraction);
          final handleCenter = trackRadius + (usableWidth * currentFraction);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              setState(() => _isDragging = true);
              _updateValue(details.localPosition.dx, width);
            },
            onPanUpdate: (details) {
              _updateValue(details.localPosition.dx, width);
            },
            onPanEnd: (details) {
              setState(() => _isDragging = false);
              widget.onChangeEnd?.call(widget.value);
            },
            onTapDown: (details) {
              setState(() => _isDragging = true);
              _updateValue(details.localPosition.dx, width);
            },
            onTapUp: (details) {
              setState(() => _isDragging = false);
              widget.onChangeEnd?.call(widget.value);
            },
            onTapCancel: () {
              setState(() => _isDragging = false);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(trackRadius),
              child: Stack(
                children: [
                  // Inactive track background
                  Container(
                    width: width,
                    height: double.infinity,
                    color: inactiveBg,
                  ),

                  // Active track fill
                  AnimatedContainer(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 100),
                    width: fillWidth,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: activeBg,
                      borderRadius: BorderRadius.circular(trackRadius),
                    ),
                  ),

                  // Expressive sliding thumb handle (Icon sliding thumb or vertical pill line)
                  Positioned(
                    left: widget.icon != null
                        ? handleCenter - 10
                        : handleCenter - 2,
                    top: currentHeight / 2 - 10,
                    child: widget.icon != null
                        ? Icon(
                            widget.icon,
                            size: 20,
                            color: handleColor.withValues(alpha: 0.95),
                          )
                        : Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: handleColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
