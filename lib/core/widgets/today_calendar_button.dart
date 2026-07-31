import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TodayCalendarIconButton extends StatelessWidget {
  const TodayCalendarIconButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Jump to today',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayNum = DateTime.now().day.toString();

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    // Lighter top binder flap strip matching Google Calendar design
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 7,
                      child: Container(
                        color: cs.onPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    // Centered date number
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: cs.onPrimary,
                            height: 1,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
