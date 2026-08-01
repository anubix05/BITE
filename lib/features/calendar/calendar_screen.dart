import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/isar_service.dart';

import '../../core/widgets/today_calendar_button.dart';
import '../../core/providers/selected_date_provider.dart';
import '../settings/providers/settings_provider.dart';

final _calendarProvider = FutureProvider.autoDispose<Map<DateTime, _DayStatus>>(
    (ref) async {
  final now = DateTime.now();
  final start =
      DateTime(now.year, now.month, 1).subtract(const Duration(days: 60));
  final meals = await isarService.getMealsInDateRange(start, now);
  // Need settings for goals
  final settings = await isarService.getOrCreateSettings();
  final goal = settings.goalCalories;
  final isWeightGain = settings.targetWeightKg > (settings.weightKg + 0.1);

  final map = <DateTime, _DayStatus>{};
  for (final m in meals) {
    final key = DateTime(m.date.year, m.date.month, m.date.day);
    final cur = map[key];
    map[key] = _DayStatus(
      calories: (cur?.calories ?? 0) + m.totalCalories,
      goal: goal,
      isWeightGain: isWeightGain,
    );
  }
  return map;
});

class _DayStatus {
  final double calories;
  final double goal;
  final bool isWeightGain;

  _DayStatus({
    required this.calories,
    required this.goal,
    this.isWeightGain = false,
  });

  bool get hasData => calories > 0;

  /// true = failed target (Over limit for weight loss, Under limit for weight gain)
  bool get isUnfavorable => isWeightGain ? calories < goal : calories > goal;

  Color get color {
    if (!hasData) return const Color(0x00000000); // No data — transparent
    if (isUnfavorable) return const Color(0xFFF87171);   // Failed target — red
    return const Color(0xFF4ADE80);               // Goal achieved — green
  }
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static final DateTime _baseDate = DateTime(2020, 1, 1);
  late PageController _pageController;
  late DateTime _focusedMonth;

  int _monthToPage(DateTime date) {
    return (date.year - _baseDate.year) * 12 + (date.month - _baseDate.month);
  }

  DateTime _pageToMonth(int page) {
    return DateTime(_baseDate.year, _baseDate.month + page, 1);
  }

  @override
  void initState() {
    super.initState();
    final selected = ref.read(selectedDateProvider);
    _focusedMonth = DateTime(selected.year, selected.month, 1);
    _pageController = PageController(initialPage: _monthToPage(_focusedMonth));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToMonth(DateTime month) {
    final page = _monthToPage(month);
    if (_pageController.hasClients &&
        _pageController.page?.round() != page) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_calendarProvider);
    final cs = Theme.of(context).colorScheme;

    final selectedDate = ref.watch(selectedDateProvider);
    final isToday = isSameDay(selectedDate, DateTime.now());

    ref.listen<DateTime>(selectedDateProvider, (previous, next) {
      final targetMonth = DateTime(next.year, next.month, 1);
      if (_focusedMonth.year != targetMonth.year ||
          _focusedMonth.month != targetMonth.month) {
        _animateToMonth(targetMonth);
        setState(() {
          _focusedMonth = targetMonth;
        });
      }
    });

    final dateParam = GoRouterState.of(context).uri.queryParameters['date'];
    if (dateParam != null) {
      final parsed = DateTime.tryParse(dateParam);
      if (parsed != null && !isSameDay(parsed, selectedDate)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedDateProvider.notifier).selectDate(parsed);
          final targetMonth = DateTime(parsed.year, parsed.month, 1);
          _animateToMonth(targetMonth);
          setState(() {
            _focusedMonth = targetMonth;
          });
        });
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM y').format(_focusedMonth),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Selected: ${DateFormat('EEE, MMM d').format(selectedDate)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!isToday)
                    TodayCalendarIconButton(
                      onPressed: () {
                        ref.read(selectedDateProvider.notifier).resetToToday();
                        final now = DateTime.now();
                        _animateToMonth(now);
                        setState(() => _focusedMonth = DateTime(now.year, now.month, 1));
                        context.goNamed('calendar');
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pushNamed('settings');
                    },
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Day labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Google Calendar style smooth horizontal page slider
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  final newMonth = _pageToMonth(page);
                  if (_focusedMonth.year != newMonth.year ||
                      _focusedMonth.month != newMonth.month) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _focusedMonth = newMonth;
                    });
                  }
                },
                itemBuilder: (context, page) {
                  final monthForPage = _pageToMonth(page);
                  return dataAsync.when(
                    data: (data) => _CalendarGrid(
                      focusedMonth: monthForPage,
                      selectedDate: selectedDate,
                      dayData: data,
                      onDayTapped: (date) {
                        ref.read(selectedDateProvider.notifier).selectDate(date);
                        _showDayMeals(context, date);
                      },
                    ),
                    loading: () => _CalendarGrid(
                      focusedMonth: monthForPage,
                      selectedDate: selectedDate,
                      dayData: const {},
                      onDayTapped: (date) {
                        ref.read(selectedDateProvider.notifier).selectDate(date);
                        _showDayMeals(context, date);
                      },
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
              ),
            ),

            // Legend
            Builder(
              builder: (context) {
                final settingsAsync = ref.watch(settingsNotifierProvider);
                final isWeightGain = settingsAsync.when(
                  data: (s) => s.targetWeightKg > (s.weightKg + 0.1),
                  loading: () => false,
                  error: (_, __) => false,
                );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _Legend(
                        color: const Color(0xFF4ADE80),
                        label: isWeightGain ? 'Goal reached' : 'Within goal',
                      ),
                      const SizedBox(width: 16),
                      _Legend(
                        color: const Color(0xFFF87171),
                        label: isWeightGain ? 'Under limit' : 'Over limit',
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: cs.primary, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDayMeals(BuildContext context, DateTime date) async {
    ref.read(selectedDateProvider.notifier).selectDate(date);
    await Future.delayed(const Duration(milliseconds: 250));
    if (context.mounted) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      context.go('/history?date=$dateStr');
    }
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.dayData,
    required this.onDayTapped,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<DateTime, _DayStatus> dayData;
  final ValueChanged<DateTime> onDayTapped;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // Monday-first offset
    int offset = firstDay.weekday - 1;
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final today = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: offset + daysInMonth,
      itemBuilder: (context, i) {
        if (i < offset) return const SizedBox();
        final day = i - offset + 1;
        final date = DateTime(focusedMonth.year, focusedMonth.month, day);
        final key = DateTime(date.year, date.month, date.day);
        final status = dayData[key];
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final isSelected = date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day;

        return _CalendarDayTile(
          day: day,
          date: date,
          status: status,
          isToday: isToday,
          isSelected: isSelected,
          onTap: onDayTapped,
        );
      },
    );
  }
}

class _CalendarDayTile extends StatefulWidget {
  const _CalendarDayTile({
    required this.day,
    required this.date,
    required this.status,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final DateTime date;
  final _DayStatus? status;
  final bool isToday;
  final bool isSelected;
  final ValueChanged<DateTime> onTap;

  @override
  State<_CalendarDayTile> createState() => _CalendarDayTileState();
}

class _CalendarDayTileState extends State<_CalendarDayTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasData = widget.status != null && widget.status!.calories > 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final targetOnly = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final isFuture = targetOnly.isAfter(todayOnly);

    final Color bgColor;
    final Color textColor;
    final Border? border;

    if (isFuture) {
      bgColor = cs.onSurface.withValues(alpha: 0.02);
      textColor = cs.onSurface.withValues(alpha: 0.25);
      border = null;
    } else if (widget.isSelected) {
      bgColor = cs.primary;
      textColor = cs.onPrimary;
      border = widget.isToday ? Border.all(color: cs.onPrimary, width: 2) : null;
    } else if (widget.isToday) {
      bgColor = cs.primary.withValues(alpha: 0.12);
      textColor = cs.primary;
      border = Border.all(color: cs.primary, width: 2);
    } else if (hasData) {
      bgColor = widget.status!.color.withValues(alpha: 0.25);
      textColor = cs.onSurface;
      border = null;
    } else {
      bgColor = cs.onSurface.withValues(alpha: 0.04);
      textColor = cs.onSurface.withValues(alpha: 0.7);
      border = null;
    }

    final displayColor = _isPressed
        ? (isFuture ? bgColor : cs.primary.withValues(alpha: 0.5))
        : bgColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (isFuture) return;
        HapticFeedback.lightImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (isFuture) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot log meals or select future dates.'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        widget.onTap(widget.date);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          border: border,
          boxShadow: widget.isSelected || _isPressed
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected || widget.isToday || _isPressed
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (hasData)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isSelected ? cs.onPrimary : widget.status!.color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
      ],
    );
  }
}
