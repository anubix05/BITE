import 'package:isar/isar.dart';

import '../models/meal.dart';
import '../models/app_settings.dart';

/// Singleton wrapper around the Isar instance.
class IsarService {
  IsarService._();

  static late Isar _isar;
  static bool _initialised = false;

  static void init(Isar isar) {
    _isar = isar;
    _initialised = true;
  }

  static Isar get instance {
    assert(_initialised, 'IsarService.init() must be called before use.');
    return _isar;
  }

  // ──────────────── Meal CRUD ────────────────

  Future<List<Meal>> getMealsForDate(DateTime date) async {
    final targetDate = DateTime(date.year, date.month, date.day);
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return _isar.meals
        .filter()
        .dateEqualTo(targetDate)
        .or()
        .dateBetween(startOfDay, endOfDay)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<Meal>> getAllMeals({int offset = 0, int limit = 50}) async {
    return _isar.meals
        .where()
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<Meal>> searchMeals(String query) async {
    return _isar.meals
        .filter()
        .originalUserInputContains(query, caseSensitive: false)
        .or()
        .aiInterpretationContains(query, caseSensitive: false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<int> saveMeal(Meal meal) async {
    return _isar.writeTxn(() => _isar.meals.put(meal));
  }

  Future<void> deleteMeal(int id) async {
    await _isar.writeTxn(() => _isar.meals.delete(id));
  }

  Future<Meal?> getMeal(int id) async {
    return _isar.meals.get(id);
  }

  Future<List<Meal>> getMealsInDateRange(DateTime start, DateTime end) async {
    final s = DateTime(start.year, start.month, start.day, 0, 0, 0, 0);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return _isar.meals
        .filter()
        .dateBetween(s, e)
        .sortByDate()
        .findAll();
  }

  Future<List<Meal>> getFavoriteMeals() async {
    return _isar.meals
        .filter()
        .isFavoriteEqualTo(true)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<Meal?> findMatchingFavoriteMeal(String query) async {
    final favorites = await getFavoriteMeals();
    final cleanQuery = query.trim().toLowerCase();
    for (final m in favorites) {
      if (m.originalUserInput.trim().toLowerCase() == cleanQuery ||
          (m.aiInterpretation != null &&
              m.aiInterpretation!.trim().toLowerCase() == cleanQuery)) {
        return m;
      }
    }
    return null;
  }

  // ──────────────── Daily totals ────────────────

  Future<Map<String, double>> getDailyTotals(DateTime date) async {
    final meals = await getMealsForDate(date);
    return {
      'calories': meals.fold(0.0, (s, m) => s + m.totalCalories),
      'protein': meals.fold(0.0, (s, m) => s + m.totalProteinG),
      'carbs': meals.fold(0.0, (s, m) => s + m.totalCarbsG),
      'fat': meals.fold(0.0, (s, m) => s + m.totalFatG),
    };
  }

  // ──────────────── Settings ────────────────

  Future<AppSettings?> getSettings() async {
    try {
      final s = await _isar.appSettings.get(1);
      if (s != null) _sanitizeSettings(s);
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<AppSettings> getOrCreateSettings() async {
    try {
      final existing = await _isar.appSettings.get(1);
      if (existing != null) {
        if (_sanitizeSettings(existing)) {
          await _isar.writeTxn(() => _isar.appSettings.put(existing));
        }
        return existing;
      }
    } catch (_) {
      // Fallback if schema migration or deserialization fails on old storage
      final fresh = AppSettings();
      await _isar.writeTxn(() => _isar.appSettings.put(fresh));
      return fresh;
    }
    final fresh = AppSettings();
    await _isar.writeTxn(() => _isar.appSettings.put(fresh));
    return fresh;
  }

  bool _sanitizeSettings(AppSettings s) {
    bool modified = false;
    if (s.heightCm <= 0 || s.heightCm.isNaN || s.heightCm.isInfinite) { s.heightCm = 170.0; modified = true; }
    if (s.weightKg <= 0 || s.weightKg.isNaN || s.weightKg.isInfinite) { s.weightKg = 70.0; modified = true; }
    if (s.ageYears <= 0) { s.ageYears = 25; modified = true; }
    if (s.gender.isEmpty) { s.gender = 'male'; modified = true; }
    if (s.targetWeightKg <= 0 || s.targetWeightKg.isNaN || s.targetWeightKg.isInfinite) { s.targetWeightKg = 70.0; modified = true; }
    if (s.weeklyRateKg <= 0 || s.weeklyRateKg.isNaN || s.weeklyRateKg.isInfinite) { s.weeklyRateKg = 0.5; modified = true; }
    return modified;
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _isar.writeTxn(() => _isar.appSettings.put(settings));
  }
}

final isarService = IsarService._();
