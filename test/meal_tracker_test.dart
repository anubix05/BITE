import 'package:flutter_test/flutter_test.dart';
import 'package:bite/core/models/meal.dart';
import 'package:bite/features/dashboard/providers/dashboard_provider.dart';
import 'package:bite/core/providers/selected_date_provider.dart';

void main() {
  group('Meal & Nutrition Calculation Tests', () {
    test('Recalculates meal totals correctly from items', () {
      final meal = Meal()
        ..originalUserInput = 'One plate chicken biryani and Pepsi'
        ..items = [
          MealItem()
            ..name = 'Chicken Biryani'
            ..servingDescription = '1 Full Plate'
            ..estimatedWeightG = 520
            ..calories = 890
            ..proteinG = 42
            ..carbsG = 95
            ..fatG = 32
            ..sugarG = 5
            ..sodiumMg = 850,
          MealItem()
            ..name = 'Pepsi'
            ..servingDescription = '1 Can (330ml)'
            ..estimatedWeightG = 330
            ..calories = 150
            ..proteinG = 0
            ..carbsG = 39
            ..fatG = 0
            ..sugarG = 39
            ..sodiumMg = 30,
        ];

      meal.recalculateTotals();

      expect(meal.totalCalories, equals(1040));
      expect(meal.totalProteinG, equals(42));
      expect(meal.totalCarbsG, equals(134));
      expect(meal.totalFatG, equals(32));
      expect(meal.totalSugarG, equals(44));
      expect(meal.totalSodiumMg, equals(880));
    });

    test('MealType infers correctly based on time of day', () {
      expect(MealType.fromTime(DateTime(2026, 7, 30, 8, 30)), equals(MealType.breakfast));
      expect(MealType.fromTime(DateTime(2026, 7, 30, 13, 15)), equals(MealType.lunch));
      expect(MealType.fromTime(DateTime(2026, 7, 30, 16, 45)), equals(MealType.snack));
      expect(MealType.fromTime(DateTime(2026, 7, 30, 20, 0)), equals(MealType.dinner));
      expect(MealType.fromTime(DateTime(2026, 7, 30, 23, 30)), equals(MealType.lateNight));
    });
  });

  group('DailySnapshot Macro & Calorie Progress Tests', () {
    test('Calculates remaining calories and progress percentage accurately', () {
      final m1 = Meal()
        ..items = [
          MealItem()..calories = 500..proteinG = 30..carbsG = 50..fatG = 15,
        ];
      m1.recalculateTotals();

      final m2 = Meal()
        ..items = [
          MealItem()..calories = 700..proteinG = 40..carbsG = 80..fatG = 20,
        ];
      m2.recalculateTotals();

      final snapshot = DailySnapshot(
        meals: [m1, m2],
        totalCalories: m1.totalCalories + m2.totalCalories,
        totalProtein: m1.totalProteinG + m2.totalProteinG,
        totalCarbs: m1.totalCarbsG + m2.totalCarbsG,
        totalFat: m1.totalFatG + m2.totalFatG,
        goalCalories: 2000,
        goalProtein: 150,
        goalCarbs: 220,
        goalFat: 65,
      );

      expect(snapshot.totalCalories, equals(1200));
      expect(snapshot.remainingCalories, equals(800));
      expect(snapshot.calorieProgress, closeTo(0.6, 0.001));
      expect(snapshot.totalProtein, equals(70));
      expect(snapshot.totalCarbs, equals(130));
      expect(snapshot.totalFat, equals(35));
    });
  });

  group('Selected Date Provider State Tests', () {
    test('isSameDay accurately compares dates ignoring time', () {
      final d1 = DateTime(2026, 7, 25, 9, 30);
      final d2 = DateTime(2026, 7, 25, 22, 15);
      final d3 = DateTime(2026, 7, 26, 9, 30);

      expect(isSameDay(d1, d2), isTrue);
      expect(isSameDay(d1, d3), isFalse);
    });

    test('SelectedDateNotifier updates and resets correctly', () {
      final notifier = SelectedDateNotifier();
      final target = DateTime(2026, 7, 20);

      notifier.selectDate(target);
      expect(isSameDay(notifier.state, target), isTrue);
      expect(notifier.isToday, isFalse);

      notifier.resetToToday();
      expect(notifier.isToday, isTrue);
    });
  });
}
