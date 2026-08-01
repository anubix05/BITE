import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/notification_service.dart';
import 'package:flutter/material.dart';

part 'settings_provider.g.dart';

@riverpod
Future<AppSettings?> appSettings(Ref ref) async {
  return isarService.getSettings();
}

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return isarService.getOrCreateSettings();
  }

  Future<void> updateGoals({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    final current = await future;
    if (calories != null) current.goalCalories = calories;
    if (protein != null) current.goalProteinG = protein;
    if (carbs != null) current.goalCarbsG = carbs;
    if (fat != null) current.goalFatG = fat;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> updatePersonalInfo({
    double? heightCm,
    double? weightKg,
    int? ageYears,
    String? gender,
    int? activityLevelIndex,
  }) async {
    final current = await future;
    if (heightCm != null) current.heightCm = heightCm;
    if (weightKg != null) current.weightKg = weightKg;
    if (ageYears != null) current.ageYears = ageYears;
    if (gender != null) current.gender = gender;
    if (activityLevelIndex != null) current.activityLevelIndex = activityLevelIndex;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> updateGoalCalculator({
    double? targetWeightKg,
    double? weeklyRateKg,
  }) async {
    final current = await future;
    if (targetWeightKg != null) current.targetWeightKg = targetWeightKg;
    if (weeklyRateKg != null) current.weeklyRateKg = weeklyRateKg;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = await future;
    current.themeModeIndex = ThemeMode.values.indexOf(mode);
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> setMaterial3Expressive(bool isExpressive) async {
    final current = await future;
    current.isMaterial3Expressive = isExpressive;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> setCustomColor(String name, int colorValue) async {
    final current = await future;
    current.customColorName = name;
    current.customColorValue = colorValue;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> setGeminiApiKey(String? key) async {
    final trimmedKey = key?.trim();
    final current = await future;
    current.geminiApiKeyOverride =
        (trimmedKey != null && trimmedKey.isNotEmpty) ? trimmedKey : null;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> setMealRemindersEnabled(bool enabled) async {
    final current = await future;
    current.mealRemindersEnabled = enabled;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
    await NotificationService.instance.updateSchedule();
  }
}
