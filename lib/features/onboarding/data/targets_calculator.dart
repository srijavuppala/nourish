import 'dart:math' as math;

import '../../../core/constants.dart';
import '../models/profile.dart';
import '../models/targets.dart';

/// Turns quiz answers into daily calorie and macro targets.
///
/// Mifflin-St Jeor for resting burn, a standard activity multiplier for total
/// burn, then a goal adjustment. Protein is set per kg of bodyweight rather
/// than as a share of calories, because a percentage gives too little protein
/// on a cut and far too much on a bulk.
abstract final class TargetsCalculator {
  /// Floors from clinical guidance, so an aggressive cut can never drop below
  /// a safe intake for a small adult.
  static const int _minCalories = 1200;
  static const double _fatShareOfCalories = 0.25;

  /// Resting energy — the calories burned doing nothing all day.
  static double basalMetabolicRate(Profile profile) {
    final base = (10 * profile.weightKg) +
        (6.25 * profile.heightCm) -
        (5 * profile.age);
    return switch (profile.sex) {
      Sex.male => base + 5,
      Sex.female => base - 161,
    };
  }

  /// Total daily burn, resting energy scaled by how active they are.
  static double totalDailyEnergyExpenditure(Profile profile) =>
      basalMetabolicRate(profile) * profile.activityLevel.multiplier;

  /// Protein per kg of bodyweight. Higher in a deficit to hold onto muscle,
  /// and higher again when the goal is explicitly to build it.
  static double proteinPerKg(Goal goal) => switch (goal) {
        Goal.lose => 2.0,
        Goal.maintain => 1.6,
        Goal.gain => 1.8,
        Goal.buildMuscle => 2.0,
      };

  static double _goalFactor(Goal goal) => switch (goal) {
        Goal.lose => 0.80,
        Goal.maintain => 1.0,
        Goal.gain => 1.15,
        Goal.buildMuscle => 1.10,
      };

  static Targets fromProfile(Profile profile) {
    final tdee = totalDailyEnergyExpenditure(profile);
    final calories = math.max(
      _minCalories,
      (tdee * _goalFactor(profile.goal)).round(),
    );

    final proteinG = (profile.weightKg * proteinPerKg(profile.goal)).round();
    final fatG = (calories * _fatShareOfCalories / 9).round();

    // Carbs take whatever calories protein and fat leave behind.
    final remaining = calories - (proteinG * 4) - (fatG * 9);
    final carbsG = math.max(0, remaining / 4).round();

    return Targets(
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      explanation: _explain(profile, tdee, calories, proteinG),
      updatedAt: DateTime.now(),
    );
  }

  /// Plain-language reasoning shown under the targets, so the numbers never
  /// arrive unexplained.
  static String _explain(
    Profile profile,
    double tdee,
    int calories,
    int proteinG,
  ) {
    final burn = tdee.round();
    final goalLine = switch (profile.goal) {
      Goal.lose => 'To lose weight we set you 20% below that, at $calories.',
      Goal.maintain => 'To maintain, we match it at $calories.',
      Goal.gain => 'To gain weight we add 15%, giving $calories.',
      Goal.buildMuscle =>
        'To build muscle we add a small 10% surplus, giving $calories.',
    };
    final perKg = proteinPerKg(profile.goal);
    return 'Based on your height, weight, age and activity level, you burn '
        'roughly $burn calories a day. $goalLine Protein is set at '
        '${perKg}g per kg of bodyweight, which is ${proteinG}g for you. '
        'These are estimates — edit them anytime in Profile.';
  }
}
