/// Shared vocabulary for the whole app. Every enum here is persisted to
/// Firestore by its [name], so renaming a value is a breaking data change.
library;

enum MealSlot {
  breakfast,
  lunch,
  dinner,
  snack;

  String get label => switch (this) {
        MealSlot.breakfast => 'Breakfast',
        MealSlot.lunch => 'Lunch',
        MealSlot.dinner => 'Dinner',
        MealSlot.snack => 'Snacks',
      };

  static MealSlot parse(String? value) => MealSlot.values.firstWhere(
        (slot) => slot.name == value,
        orElse: () => MealSlot.snack,
      );
}

enum Goal {
  lose,
  maintain,
  gain,
  buildMuscle;

  String get label => switch (this) {
        Goal.lose => 'Lose weight',
        Goal.maintain => 'Maintain',
        Goal.gain => 'Gain weight',
        Goal.buildMuscle => 'Build muscle',
      };

  static Goal parse(String? value) => Goal.values.firstWhere(
        (goal) => goal.name == value,
        orElse: () => Goal.maintain,
      );
}

enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  String get label => switch (this) {
        ActivityLevel.sedentary => 'Mostly sitting',
        ActivityLevel.light => 'Light activity',
        ActivityLevel.moderate => 'Moderately active',
        ActivityLevel.active => 'Very active',
        ActivityLevel.veryActive => 'Athlete or physical job',
      };

  String get detail => switch (this) {
        ActivityLevel.sedentary => 'Desk job, little exercise',
        ActivityLevel.light => 'Exercise 1-3 days a week',
        ActivityLevel.moderate => 'Exercise 3-5 days a week',
        ActivityLevel.active => 'Exercise 6-7 days a week',
        ActivityLevel.veryActive => 'Training twice a day',
      };

  /// Standard Mifflin-St Jeor activity multipliers.
  double get multiplier => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };

  static ActivityLevel parse(String? value) => ActivityLevel.values.firstWhere(
        (level) => level.name == value,
        orElse: () => ActivityLevel.moderate,
      );
}

enum DietType {
  omnivore,
  vegetarian,
  vegan,
  pescatarian;

  String get label => switch (this) {
        DietType.omnivore => 'I eat everything',
        DietType.vegetarian => 'Vegetarian',
        DietType.vegan => 'Vegan',
        DietType.pescatarian => 'Pescatarian',
      };

  static DietType parse(String? value) => DietType.values.firstWhere(
        (diet) => diet.name == value,
        orElse: () => DietType.omnivore,
      );
}

enum Sex {
  female,
  male;

  String get label => switch (this) {
        Sex.female => 'Female',
        Sex.male => 'Male',
      };

  static Sex parse(String? value) => Sex.values.firstWhere(
        (sex) => sex.name == value,
        orElse: () => Sex.female,
      );
}

/// How a planned meal actually went on a given day.
enum MealStatus {
  ate,
  partial,
  skipped;

  static MealStatus parse(String? value) => MealStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => MealStatus.skipped,
      );
}

/// Firestore layout. Everything a user owns hangs off `users/{uid}` so the
/// security rules stay a single ownership check.
abstract final class Paths {
  static String user(String uid) => 'users/$uid';
  static String profile(String uid) => 'users/$uid/profile/main';
  static String targets(String uid) => 'users/$uid/targets/current';
  static String planMeals(String uid) => 'users/$uid/planMeals';
  static String chatLog(String uid) => 'users/$uid/chatLog';
  static String days(String uid) => 'users/$uid/days';
  static String notificationSettings(String uid) =>
      'users/$uid/settings/notifications';
}

/// `yyyy-MM-dd` in the device's local zone — the document id for a day.
String dayId(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
