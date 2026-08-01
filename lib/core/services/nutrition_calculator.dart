import 'dart:math';

class NutritionResult {
  final double bmr;
  final double tdee;
  final double targetCalories;
  final double targetProteinG;
  final double targetCarbsG;
  final double targetFatG;
  final String goalType; // 'loss', 'gain', 'maintain'
  final double dailyAdjustment;

  const NutritionResult({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.targetProteinG,
    required this.targetCarbsG,
    required this.targetFatG,
    required this.goalType,
    required this.dailyAdjustment,
  });
}

class BmiResult {
  final double bmi;
  final String category; // 'Underweight', 'Normal weight', 'Overweight', 'Obese'
  const BmiResult({required this.bmi, required this.category});
}

class NutritionCalculator {
  static const List<double> activityMultipliers = [
    1.20,  // 0: Sedentary
    1.375, // 1: Lightly Active
    1.55,  // 2: Moderately Active
    1.725, // 3: Very Active
    1.90,  // 4: Extra Active
  ];

  static const List<String> activityLabels = [
    'Sedentary (Little or no exercise)',
    'Lightly Active (Exercise 1-3 days/wk)',
    'Moderately Active (Exercise 3-5 days/wk)',
    'Very Active (Hard exercise 6-7 days/wk)',
    'Extra Active (Physical job / intense training)',
  ];

  static BmiResult calculateBmi({
    required double heightCm,
    required double weightKg,
  }) {
    if (heightCm <= 0 || weightKg <= 0) {
      return const BmiResult(bmi: 0, category: 'Unknown');
    }
    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);
    final rounded = double.parse(bmi.toStringAsFixed(1));

    String category;
    if (rounded < 18.5) {
      category = 'Underweight';
    } else if (rounded < 25.0) {
      category = 'Normal weight';
    } else if (rounded < 30.0) {
      category = 'Overweight';
    } else {
      category = 'Obese';
    }

    return BmiResult(bmi: rounded, category: category);
  }

  /// Calculates BMR using the Mifflin-St Jeor Equation
  static double calculateBmr({
    required double heightCm,
    required double weightKg,
    required int ageYears,
    required String gender,
  }) {
    if (heightCm <= 0 || weightKg <= 0 || ageYears <= 0) return 1800.0;
    
    final isMale = gender.toLowerCase() == 'male';
    if (isMale) {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) + 5;
    } else {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 161;
    }
  }

  /// Calculates complete nutrition targets based on user metrics and goals
  static NutritionResult calculateTargets({
    required double heightCm,
    required double weightKg,
    required int ageYears,
    required String gender,
    required int activityLevelIndex,
    required double targetWeightKg,
    required double weeklyRateKg,
  }) {
    final bmr = calculateBmr(
      heightCm: heightCm,
      weightKg: weightKg,
      ageYears: ageYears,
      gender: gender,
    );

    final validActivityIndex = activityLevelIndex.clamp(0, activityMultipliers.length - 1);
    final multiplier = activityMultipliers[validActivityIndex];
    final tdee = bmr * multiplier;

    // 1 kg body fat is ~7700 kcal
    final dailyAdjustment = (weeklyRateKg * 7700 / 7);

    String goalType = 'maintain';
    double targetCalories = tdee;

    const weightTolerance = 0.1; // 100 grams
    if (targetWeightKg < weightKg - weightTolerance) {
      goalType = 'loss';
      targetCalories = max(1200.0, tdee - dailyAdjustment);
    } else if (targetWeightKg > weightKg + weightTolerance) {
      goalType = 'gain';
      targetCalories = tdee + dailyAdjustment;
    } else {
      goalType = 'maintain';
      targetCalories = tdee;
    }

    // Round target calories to nearest integer for clean display
    targetCalories = targetCalories.roundToDouble();

    // Standard Balanced Macro Split:
    // Protein: 30% of total calories (4 kcal/g)
    // Fat: 25% of total calories (9 kcal/g)
    // Carbs: 45% of total calories (4 kcal/g)
    final proteinG = ((targetCalories * 0.30) / 4).roundToDouble();
    final fatG = ((targetCalories * 0.25) / 9).roundToDouble();
    final carbsG = ((targetCalories * 0.45) / 4).roundToDouble();

    return NutritionResult(
      bmr: bmr.roundToDouble(),
      tdee: tdee.roundToDouble(),
      targetCalories: targetCalories,
      targetProteinG: proteinG,
      targetCarbsG: carbsG,
      targetFatG: fatG,
      goalType: goalType,
      dailyAdjustment: dailyAdjustment.roundToDouble(),
    );
  }
}
