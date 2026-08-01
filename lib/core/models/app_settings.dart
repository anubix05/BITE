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

  // Personal Info
  double heightCm = 170.0;
  double weightKg = 70.0;
  int ageYears = 25;
  String gender = 'male'; // 'male' or 'female'
  int activityLevelIndex = 1; // 0=sedentary, 1=light, 2=moderate, 3=active, 4=extra active

  // Goal Calculator
  double targetWeightKg = 70.0;
  double weeklyRateKg = 0.5; // 0.25, 0.5, or 1.0 kg/week

  // Theme
  int themeModeIndex = 0; // 0=system, 1=light, 2=dark
  bool isMaterial3Expressive = false; // false=normal theme, true=material u 3 expressive
  String customColorName = 'Monochrome';
  int customColorValue = 0xFF000000;

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
