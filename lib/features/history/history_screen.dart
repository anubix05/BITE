import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/isar_service.dart';
import '../../core/models/meal.dart';
import '../../core/widgets/today_calendar_button.dart';
import '../../core/providers/selected_date_provider.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────
final _historyDateProvider =
    FutureProvider.autoDispose.family<List<Meal>, ({String query, DateTime? date})>(
  (ref, params) async {
    if (params.date != null) {
      final meals = await isarService.getMealsForDate(params.date!);
      if (params.query.isEmpty) return meals;
      final q = params.query.toLowerCase();
      return meals
          .where((m) =>
              (m.aiInterpretation?.toLowerCase().contains(q) ?? false) ||
              m.originalUserInput.toLowerCase().contains(q))
          .toList();
    }
    if (params.query.isEmpty) return isarService.getAllMeals(limit: 100);
    return isarService.searchMeals(params.query);
  },
);

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

enum _HistoryTab { logs, insights }

// ─────────────────────────────────────────────────────────────────
// Unified History Screen
// ─────────────────────────────────────────────────────────────────
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryTab _activeTab = _HistoryTab.logs;
  final _searchController = TextEditingController();
  String _query = '';
  AnalyticsPeriod _analyticsPeriod = AnalyticsPeriod.weekly;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final dateParam = GoRouterState.of(context).uri.queryParameters['date'];
    if (dateParam != null) {
      final parsed = DateTime.tryParse(dateParam);
      if (parsed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedDateProvider.notifier).selectDate(parsed);
        });
      }
    }

    final selectedDate = ref.watch(selectedDateProvider);
    final isToday = isSameDay(selectedDate, DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header Title & Settings button ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.goNamed('calendar');
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(selectedDate).toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM dd').format(selectedDate),
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!isToday)
                      TodayCalendarIconButton(
                        onPressed: () {
                          ref.read(selectedDateProvider.notifier).resetToToday();
                        },
                      ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.pushNamed('settings');
                      },
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
            ),

            // ── Unified Tab Segmented Switch ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SegmentedButton<_HistoryTab>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _HistoryTab.logs,
                      icon: Icon(Icons.list_alt_rounded),
                      label: Text('Meal Logs'),
                    ),
                    ButtonSegment(
                      value: _HistoryTab.insights,
                      icon: Icon(Icons.bar_chart_rounded),
                      label: Text('Insights'),
                    ),
                  ],
                  selected: {_activeTab},
                  onSelectionChanged: (s) {
                    HapticFeedback.lightImpact();
                    setState(() => _activeTab = s.first);
                  },
                ),
              ),
            ),

            // ── Tab 1: Meal Logs (Default load) ──
            if (_activeTab == _HistoryTab.logs) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search meals...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
              ),
              _buildLogsSliver(ref, cs, selectedDate),
            ] else ...[
              // ── Tab 2: Insights (Only built when selected) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SegmentedButton<AnalyticsPeriod>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: AnalyticsPeriod.daily, label: Text('7 Days')),
                      ButtonSegment(
                          value: AnalyticsPeriod.weekly,
                          label: Text('4 Weeks')),
                      ButtonSegment(
                          value: AnalyticsPeriod.monthly,
                          label: Text('3 Months')),
                    ],
                    selected: {_analyticsPeriod},
                    onSelectionChanged: (s) {
                      HapticFeedback.lightImpact();
                      setState(() => _analyticsPeriod = s.first);
                    },
                  ),
                ),
              ),
              _buildInsightsSliver(ref, cs, selectedDate),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsSliver(WidgetRef ref, ColorScheme cs, DateTime? selectedDate) {
    final mealsAsync =
        ref.watch(_historyDateProvider((query: _query, date: selectedDate)));

    return mealsAsync.when(
      data: (meals) {
        if (meals.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 56,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _query.isEmpty
                        ? 'No meals logged yet'
                        : 'No results for "$_query"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final grouped = <String, List<Meal>>{};
        for (final meal in meals) {
          final key = DateFormat('EEEE, d MMMM y').format(meal.date);
          grouped.putIfAbsent(key, () => []).add(meal);
        }

        final entries = grouped.entries.toList();
        return SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                ...entry.value.map(
                  (meal) => _HistoryMealTile(
                    meal: meal,
                    onDeleted: () => ref.invalidate(_historyDateProvider),
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (e, _) => SliverFillRemaining(
        child: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildInsightsSliver(WidgetRef ref, ColorScheme cs, DateTime selectedDate) {
    final now = DateTime.now();
    final endDate = selectedDate.isAfter(now) ? now : selectedDate;
    final dataAsync = ref.watch(_analyticsProvider((period: _analyticsPeriod, endDate: endDate)));

    return dataAsync.when(
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
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (e, _) => SliverFillRemaining(
        child: Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Meal Tile
// ─────────────────────────────────────────────────────────────────
class _HistoryMealTile extends StatelessWidget {
  const _HistoryMealTile({required this.meal, required this.onDeleted});
  final Meal meal;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(meal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: cs.error,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete meal?'),
            content: const Text('This action cannot be undone.'),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ctx.pop(false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(ctx)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ctx.pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await isarService.deleteMeal(meal.id);
        onDeleted();
      },
      child: ListTile(
        onTap: () => context.pushNamed('meal_detail',
            pathParameters: {'id': meal.id.toString()}),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              meal.time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        title: Text(
          meal.aiInterpretation ?? meal.originalUserInput,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${meal.mealType.label} • ${meal.items.length} items',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
        ),
        trailing: Text(
          '${meal.totalCalories.toStringAsFixed(0)} kcal',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Insights Chart Section
// ─────────────────────────────────────────────────────────────────
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
    final avg =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
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
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
