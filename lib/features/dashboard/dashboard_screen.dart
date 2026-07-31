import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/today_calendar_button.dart';
import '../../core/providers/selected_date_provider.dart';
import '../../core/widgets/macro_ring.dart';
import '../../core/models/meal.dart';
import 'providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(todaySnapshotProvider);
    final cs = Theme.of(context).colorScheme;

    final selectedDate = ref.watch(selectedDateProvider);
    final isToday = isSameDay(selectedDate, DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(todaySnapshotProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App bar ──
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
                      ),
                    ],
                  ),
                ),
              ),

              // ── Nutrition snapshot ──
              SliverToBoxAdapter(
                child: snapshot.when(
                  data: (s) => _NutritionSnapshot(snapshot: s),
                  loading: () => const _NutritionSnapshot(
                    snapshot: DailySnapshot(
                      meals: [],
                      totalCalories: 0,
                      totalProtein: 0,
                      totalCarbs: 0,
                      totalFat: 0,
                      goalCalories: 2000,
                      goalProtein: 150,
                      goalCarbs: 220,
                      goalFat: 65,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),

              // ── Meals header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Row(
                    children: [
                      Text(
                        isToday
                            ? "Today's Meals"
                            : "Meals (${DateFormat('MMM d').format(selectedDate)})",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      snapshot.maybeWhen(
                        data: (s) => Text(
                          '${s.meals.length} logged',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                        ),
                        orElse: () => const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Meal timeline ──
              snapshot.when(
                data: (s) => s.meals.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyState())
                    : SliverList.separated(
                        itemCount: s.meals.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _MealCard(meal: s.meals[i]),
                      ),
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Nutrition Snapshot Widget
// ─────────────────────────────────────────────────────────────────
class _NutritionSnapshot extends StatelessWidget {
  const _NutritionSnapshot({required this.snapshot});
  final DailySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = snapshot.remainingCalories;
    final isCalorieOver = snapshot.totalCalories > snapshot.goalCalories && snapshot.goalCalories > 0;
    final calorieOverAmount = snapshot.totalCalories - snapshot.goalCalories;
    final overColor = const Color(0xFFF87171);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Calories center
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                snapshot.totalCalories.toStringAsFixed(0),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: isCalorieOver ? overColor : cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/ ${snapshot.goalCalories.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.65),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isCalorieOver
                ? '+${calorieOverAmount.toStringAsFixed(0)} kcal'
                : remaining > 0
                    ? '${remaining.toStringAsFixed(0)} kcal remaining'
                    : 'Daily goal reached! 🎉',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isCalorieOver
                      ? overColor
                      : cs.onPrimaryContainer.withValues(alpha: 0.75),
                  fontWeight: isCalorieOver ? FontWeight.w700 : FontWeight.normal,
                ),
          ),

          // Calorie progress bar
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: snapshot.calorieProgress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCalorieOver ? overColor : cs.primary,
                ),
                minHeight: 6,
              ),
            ),
          ),

          // Macro rings
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroRing(
                label: 'Protein',
                value: snapshot.totalProtein,
                goal: snapshot.goalProtein,
                unit: 'g',
                color: cs.onPrimaryContainer,
                size: 80,
                strokeWidth: 7,
              ),
              MacroRing(
                label: 'Carbs',
                value: snapshot.totalCarbs,
                goal: snapshot.goalCarbs,
                unit: 'g',
                color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                size: 80,
                strokeWidth: 7,
              ),
              MacroRing(
                label: 'Fat',
                value: snapshot.totalFat,
                goal: snapshot.goalFat,
                unit: 'g',
                color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                size: 80,
                strokeWidth: 7,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Meal Card
// ─────────────────────────────────────────────────────────────────
class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () => context.pushNamed('meal_detail',
            pathParameters: {'id': meal.id.toString()}),
        borderRadius: BorderRadius.circular(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Time + type badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.time,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        meal.mealType.label,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Meal info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.aiInterpretation ?? meal.originalUserInput,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meal.items.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meal.items.map((i) => i.name).join(', '),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5),
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Calories
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      meal.totalCalories.toStringAsFixed(0),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                    ),
                    Text(
                      'kcal',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_rounded,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing logged yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Log Meal to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
