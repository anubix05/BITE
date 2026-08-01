import 'package:flutter_test/flutter_test.dart';
import 'package:bite/core/models/app_settings.dart';

void main() {
  test('AppSettings default values sanity check', () {
    final settings = AppSettings();
    expect(settings.heightCm, equals(170.0));
    expect(settings.weightKg, equals(70.0));
    expect(settings.ageYears, equals(25));
    expect(settings.gender, equals('male'));
    expect(settings.activityLevelIndex, equals(1));
    expect(settings.targetWeightKg, equals(70.0));
    expect(settings.weeklyRateKg, equals(0.5));
  });
}
