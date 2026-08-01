import 'package:flutter_test/flutter_test.dart';
import 'package:bite/core/services/nutrition_calculator.dart';

void main() {
  group('NutritionCalculator Tests', () {
    test('Calculates BMR correctly for male and female using Mifflin-St Jeor', () {
      // Male: 10*70 + 6.25*175 - 5*25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
      final maleBmr = NutritionCalculator.calculateBmr(
        heightCm: 175,
        weightKg: 70,
        ageYears: 25,
        gender: 'male',
      );
      expect(maleBmr, closeTo(1673.75, 0.1));

      // Female: 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
      final femaleBmr = NutritionCalculator.calculateBmr(
        heightCm: 165,
        weightKg: 60,
        ageYears: 30,
        gender: 'female',
      );
      expect(femaleBmr, closeTo(1320.25, 0.1));
    });

    test('Calculates weight loss target with 0.5 kg/week deficit', () {
      final result = NutritionCalculator.calculateTargets(
        heightCm: 175,
        weightKg: 80,
        ageYears: 25,
        gender: 'male',
        activityLevelIndex: 1, // Lightly active (1.375)
        targetWeightKg: 70,    // Weight loss
        weeklyRateKg: 0.5,     // -550 kcal/day
      );

      expect(result.goalType, equals('loss'));
      expect(result.targetCalories, lessThan(result.tdee));
      expect(result.targetCalories, equals(result.tdee - 550));
      expect(result.targetProteinG, closeTo((result.targetCalories * 0.30) / 4, 1.0));
      expect(result.targetCarbsG, closeTo((result.targetCalories * 0.45) / 4, 1.0));
      expect(result.targetFatG, closeTo((result.targetCalories * 0.25) / 9, 1.0));
    });

    test('Calculates weight gain target with 0.25 kg/week surplus', () {
      final result = NutritionCalculator.calculateTargets(
        heightCm: 175,
        weightKg: 65,
        ageYears: 25,
        gender: 'male',
        activityLevelIndex: 1, // Lightly active (1.375)
        targetWeightKg: 70,    // Weight gain
        weeklyRateKg: 0.25,    // +275 kcal/day
      );

      expect(result.goalType, equals('gain'));
      expect(result.targetCalories, greaterThan(result.tdee));
      expect(result.targetCalories, equals(result.tdee + 275));
    });

    test('Calculates maintenance target when target weight equals current weight', () {
      final result = NutritionCalculator.calculateTargets(
        heightCm: 170,
        weightKg: 70,
        ageYears: 30,
        gender: 'female',
        activityLevelIndex: 2, // Moderately active
        targetWeightKg: 70,    // Maintenance
        weeklyRateKg: 0.5,
      );

      expect(result.goalType, equals('maintain'));
      expect(result.targetCalories, equals(result.tdee));
    });
  });
}
