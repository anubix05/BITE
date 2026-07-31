import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/models/app_settings.dart';
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
    final current = await future;
    current.geminiApiKeyOverride = key;
    await isarService.saveSettings(current);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }
}
