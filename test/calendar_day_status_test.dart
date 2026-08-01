import 'package:flutter_test/flutter_test.dart';

class DayStatusTest {
  final double calories;
  final double goal;
  final bool isWeightGain;

  DayStatusTest({
    required this.calories,
    required this.goal,
    this.isWeightGain = false,
  });

  bool get hasData => calories > 0;
  bool get isUnfavorable => isWeightGain ? calories < goal : calories > goal;
  String get statusLabel => isUnfavorable
      ? (isWeightGain ? 'Under limit' : 'Over limit')
      : (isWeightGain ? 'Goal reached' : 'Within goal');
}

void main() {
  group('Calendar Day Status Tests', () {
    test('Weight loss goal: calories exceeding goal is marked unfavorable (over limit)', () {
      final status = DayStatusTest(calories: 2200, goal: 2000, isWeightGain: false);
      expect(status.isUnfavorable, isTrue);
      expect(status.statusLabel, equals('Over limit'));
    });

    test('Weight loss goal: calories within goal is marked favorable (within goal)', () {
      final status = DayStatusTest(calories: 1800, goal: 2000, isWeightGain: false);
      expect(status.isUnfavorable, isFalse);
      expect(status.statusLabel, equals('Within goal'));
    });

    test('Weight gain goal: calories below goal is marked unfavorable (under limit)', () {
      final status = DayStatusTest(calories: 2200, goal: 2500, isWeightGain: true);
      expect(status.isUnfavorable, isTrue);
      expect(status.statusLabel, equals('Under limit'));
    });

    test('Weight gain goal: calories meeting or exceeding goal is marked favorable (goal reached)', () {
      final status = DayStatusTest(calories: 2600, goal: 2500, isWeightGain: true);
      expect(status.isUnfavorable, isFalse);
      expect(status.statusLabel, equals('Goal reached'));
    });
  });
}
