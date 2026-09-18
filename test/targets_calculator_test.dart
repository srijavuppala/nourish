import 'package:flutter_test/flutter_test.dart';
import 'package:nourish/core/constants.dart';
import 'package:nourish/features/onboarding/data/targets_calculator.dart';
import 'package:nourish/features/onboarding/models/profile.dart';

void main() {
  group('basalMetabolicRate', () {
    test('matches Mifflin-St Jeor for men', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 1780
      const profile = Profile(
        sex: Sex.male,
        age: 30,
        heightCm: 180,
        weightKg: 80,
      );
      expect(TargetsCalculator.basalMetabolicRate(profile), closeTo(1780, 0.5));
    });

    test('matches Mifflin-St Jeor for women', () {
      // 10*65 + 6.25*165 - 5*30 - 161 = 1370.25
      const profile = Profile(
        sex: Sex.female,
        age: 30,
        heightCm: 165,
        weightKg: 65,
      );
      expect(
        TargetsCalculator.basalMetabolicRate(profile),
        closeTo(1370.25, 0.5),
      );
    });
  });

  group('fromProfile', () {
    const base = Profile(
      sex: Sex.male,
      age: 30,
      heightCm: 180,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
    );

    test('a cut lands below maintenance and a bulk above it', () {
      final maintain =
          TargetsCalculator.fromProfile(base.copyWith(goal: Goal.maintain));
      final lose = TargetsCalculator.fromProfile(base.copyWith(goal: Goal.lose));
      final gain = TargetsCalculator.fromProfile(base.copyWith(goal: Goal.gain));

      expect(lose.calories, lessThan(maintain.calories));
      expect(gain.calories, greaterThan(maintain.calories));
    });

    test('never drops below the 1200 kcal floor', () {
      // A small, sedentary person on an aggressive cut.
      const small = Profile(
        sex: Sex.female,
        goal: Goal.lose,
        age: 65,
        heightCm: 150,
        weightKg: 45,
        activityLevel: ActivityLevel.sedentary,
      );
      expect(TargetsCalculator.fromProfile(small).calories, greaterThanOrEqualTo(1200));
    });

    test('sets protein from bodyweight, higher on a cut than at maintenance', () {
      final lose = TargetsCalculator.fromProfile(base.copyWith(goal: Goal.lose));
      final maintain =
          TargetsCalculator.fromProfile(base.copyWith(goal: Goal.maintain));

      expect(lose.proteinG, 160); // 80kg * 2.0
      expect(maintain.proteinG, 128); // 80kg * 1.6
      expect(lose.proteinG, greaterThan(maintain.proteinG));
    });

    test('macros add up to roughly the calorie target', () {
      final targets = TargetsCalculator.fromProfile(base);
      final fromMacros =
          targets.proteinG * 4 + targets.carbsG * 4 + targets.fatG * 9;

      // Rounding each macro to a whole gram leaves a little slack.
      expect((fromMacros - targets.calories).abs(), lessThan(15));
    });

    test('a more active person gets more calories', () {
      final sedentary = TargetsCalculator.fromProfile(
        base.copyWith(activityLevel: ActivityLevel.sedentary),
      );
      final active = TargetsCalculator.fromProfile(
        base.copyWith(activityLevel: ActivityLevel.veryActive),
      );

      expect(active.calories, greaterThan(sedentary.calories));
    });

    test('explains the numbers rather than just stating them', () {
      final targets = TargetsCalculator.fromProfile(base);
      expect(targets.explanation, contains('burn'));
      expect(targets.explanation, contains('estimates'));
    });

    test('carbs never go negative when protein and fat fill the budget', () {
      // Heavy and cutting: protein alone is a large share of the target.
      const heavy = Profile(
        sex: Sex.male,
        goal: Goal.lose,
        age: 40,
        heightCm: 165,
        weightKg: 150,
        activityLevel: ActivityLevel.sedentary,
      );
      expect(TargetsCalculator.fromProfile(heavy).carbsG, greaterThanOrEqualTo(0));
    });
  });
}
