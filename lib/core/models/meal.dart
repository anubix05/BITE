import 'package:isar/isar.dart';

part 'meal.g.dart';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  lateNight;

  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
      case MealType.lateNight:
        return 'Late Night';
    }
  }

  static MealType fromTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 15 && hour < 18) return MealType.snack;
    if (hour >= 18 && hour < 22) return MealType.dinner;
    return MealType.lateNight;
  }
}

@embedded
class MealItem {
  String name = '';
  String servingDescription = '';
  double estimatedWeightG = 0;
  double calories = 0;
  double proteinG = 0;
  double carbsG = 0;
  double fatG = 0;
  double sugarG = 0;
  double sodiumMg = 0;

  // Original AI values (preserved if user edits)
  double? aiCalories;
  double? aiProteinG;
  double? aiCarbsG;
  double? aiFatG;
}

@collection
class Meal {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  @Index()
  late DateTime date; // Normalised to midnight for grouping

  late String time; // Display time e.g. "08:15"

  @enumerated
  late MealType mealType;

  late String originalUserInput; // Raw user text
  String? aiInterpretation; // AI's summary name
  String? imagePath;
  String? notes;

  double aiConfidence = 0;
  bool userEdited = false;

  // Computed totals
  double totalCalories = 0;
  double totalProteinG = 0;
  double totalCarbsG = 0;
  double totalFatG = 0;
  double totalSugarG = 0;
  double totalSodiumMg = 0;

  List<MealItem> items = [];
  bool isFavorite = false;

  void recalculateTotals() {
    totalCalories = items.fold(0, (s, i) => s + i.calories);
    totalProteinG = items.fold(0, (s, i) => s + i.proteinG);
    totalCarbsG = items.fold(0, (s, i) => s + i.carbsG);
    totalFatG = items.fold(0, (s, i) => s + i.fatG);
    totalSugarG = items.fold(0, (s, i) => s + i.sugarG);
    totalSodiumMg = items.fold(0, (s, i) => s + i.sodiumMg);
  }
}
