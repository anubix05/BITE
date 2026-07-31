import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/models/meal.dart';
import '../../../core/providers/selected_date_provider.dart';

part 'dashboard_provider.g.dart';

class DailySnapshot {
  final List<Meal> meals;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double goalCalories;
  final double goalProtein;
  final double goalCarbs;
  final double goalFat;

  const DailySnapshot({
    required this.meals,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.goalCalories,
    required this.goalProtein,
    required this.goalCarbs,
    required this.goalFat,
  });

  double get remainingCalories =>
      (goalCalories - totalCalories).clamp(0, goalCalories);
  double get calorieProgress =>
      goalCalories > 0 ? (totalCalories / goalCalories).clamp(0, 1) : 0;
}

@riverpod
Future<DailySnapshot> todaySnapshot(Ref ref) async {
  final selectedDate = ref.watch(selectedDateProvider);
  final settings = await isarService.getOrCreateSettings();
  final meals = await isarService.getMealsForDate(selectedDate);

  final totalCal = meals.fold(0.0, (s, m) => s + m.totalCalories);
  final totalPro = meals.fold(0.0, (s, m) => s + m.totalProteinG);
  final totalCarb = meals.fold(0.0, (s, m) => s + m.totalCarbsG);
  final totalFat = meals.fold(0.0, (s, m) => s + m.totalFatG);

  return DailySnapshot(
    meals: meals,
    totalCalories: totalCal,
    totalProtein: totalPro,
    totalCarbs: totalCarb,
    totalFat: totalFat,
    goalCalories: settings.goalCalories,
    goalProtein: settings.goalProteinG,
    goalCarbs: settings.goalCarbsG,
    goalFat: settings.goalFatG,
  );
}
