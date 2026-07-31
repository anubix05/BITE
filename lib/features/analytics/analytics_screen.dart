import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/isar_service.dart';
import '../../core/models/meal.dart';
import '../../core/theme/app_theme.dart';

import '../../core/providers/selected_date_provider.dart';

enum AnalyticsPeriod { daily, weekly, monthly }

final _analyticsProvider = FutureProvider.autoDispose
    .family<List<_DayData>, ({AnalyticsPeriod period, DateTime endDate})>((ref, params) async {
  final endDate = params.endDate;
  DateTime start;
  switch (params.period) {
    case AnalyticsPeriod.daily:
      start = endDate.subtract(const Duration(days: 6));
    case AnalyticsPeriod.weekly:
      start = endDate.subtract(const Duration(days: 27));
    case AnalyticsPeriod.monthly:
      start = endDate.subtract(const Duration(days: 89));
  }
  final meals = await isarService.getMealsInDateRange(start, endDate);
  return _groupMealsByDay(meals, start, endDate);
});

List<_DayData> _groupMealsByDay(
    List<Meal> meals, DateTime start, DateTime end) {
  final map = <String, _DayData>{};
  var cur = DateTime(start.year, start.month, start.day);
  while (!cur.isAfter(end)) {
    map[_key(cur)] = _DayData(date: cur);
    cur = cur.add(const Duration(days: 1));
  }
  for (final m in meals) {
    final k = _key(m.date);
    map[k]?.addMeal(m);
  }
  return map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

class _DayData {
  final DateTime date;
  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  _DayData({required this.date});

  void addMeal(Meal m) {
    calories += m.totalCalories;
    protein += m.totalProteinG;
    carbs += m.totalCarbsG;
    fat += m.totalFatG;
  }
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.weekly;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final endDate = selectedDate.isAfter(now) ? now : selectedDate;
    final dataAsync = ref.watch(_analyticsProvider((period: _period, endDate: endDate)));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Insights',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => context.goNamed('settings'),
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<AnalyticsPeriod>(
                  segments: const [
                    ButtonSegment(
                        value: AnalyticsPeriod.daily,
                        label: Text('7 Days')),
                    ButtonSegment(
                        value: AnalyticsPeriod.weekly,
                        label: Text('4 Weeks')),
                    ButtonSegment(
                        value: AnalyticsPeriod.monthly,
                        label: Text('3 Months')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) =>
                      setState(() => _period = s.first),
                ),
              ),
            ),
            dataAsync.when(
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _ChartSection(
                    title: 'Calories',
                    data: data,
                    getValue: (d) => d.calories,
                    color: cs.primary,
                    unit: 'kcal',
                  ),
                  const SizedBox(height: 24),
                  _ChartSection(
                    title: 'Macros (avg)',
                    data: data,
                    getValue: (d) => d.protein,
                    color: AppTheme.proteinColor,
                    unit: 'g protein',
                    secondary: data,
                    getSecondary: (d) => d.carbs,
                    secondaryColor: AppTheme.carbsColor,
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.data,
    required this.getValue,
    required this.color,
    required this.unit,
    this.secondary,
    this.getSecondary,
    this.secondaryColor,
  });

  final String title;
  final List<_DayData> data;
  final double Function(_DayData) getValue;
  final Color color;
  final String unit;
  final List<_DayData>? secondary;
  final double Function(_DayData)? getSecondary;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final values = data.map(getValue).toList();
    final avg = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;
    final maxVal =
        values.isEmpty ? 100.0 : (values.reduce((a, b) => a > b ? a : b) * 1.2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'avg ${avg.toStringAsFixed(0)} $unit',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxVal,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length) {
                          return const SizedBox();
                        }
                        if (data.length > 14 && i % 7 != 0) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('d/M').format(data[i].date),
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(data.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: getValue(data[i]),
                        color: color,
                        width: data.length > 30 ? 4 : 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
