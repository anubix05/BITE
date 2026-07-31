import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = 1; // Singleton

  // Nutrition goals
  double goalCalories = 2000;
  double goalProteinG = 150;
  double goalCarbsG = 220;
  double goalFatG = 65;

  // Theme
  int themeModeIndex = 0; // 0=system, 1=light, 2=dark
  bool isMaterial3Expressive = false; // false=normal theme, true=material u 3 expressive
  String customColorName = 'Default';
  int customColorValue = 0xFF27272A;

  // AI
  String? geminiApiKeyOverride; // Optional user-supplied key override

  // Units
  bool useMetric = true;

  // Image compression
  int imageQuality = 85; // 0-100

  // Onboarding complete
  bool onboardingComplete = false;
}

/// Helper to convert stored int back to ThemeMode.
extension AppSettingsTheme on AppSettings {
  ThemeMode get themeMode => ThemeMode.values[themeModeIndex];
}
