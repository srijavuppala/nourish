import '../../../core/constants.dart';
import '../../plan/models/meal_item.dart';

/// One planned meal, as it actually went today.
class LoggedMeal {
  const LoggedMeal({
    required this.mealId,
    required this.slot,
    required this.label,
    required this.status,
    required this.items,
  });

  final String mealId;
  final MealSlot slot;
  final String label;
  final MealStatus status;

  /// What was actually eaten. Empty when [status] is [MealStatus.skipped];
  /// scaled down from the plan when it is [MealStatus.partial].
  final List<MealItem> items;

  double get kcal => items.fold(0, (sum, item) => sum + item.kcal);
  double get proteinG => items.fold(0, (sum, item) => sum + item.proteinG);
  double get carbsG => items.fold(0, (sum, item) => sum + item.carbsG);
  double get fatG => items.fold(0, (sum, item) => sum + item.fatG);

  Map<String, dynamic> toMap() => {
        'mealId': mealId,
        'slot': slot.name,
        'label': label,
        'status': status.name,
        'items': items.map((item) => item.toMap()).toList(),
      };

  factory LoggedMeal.fromMap(Map<String, dynamic> map) => LoggedMeal(
        mealId: (map['mealId'] as String?) ?? '',
        slot: MealSlot.parse(map['slot'] as String?),
        label: (map['label'] as String?) ?? '',
        status: MealStatus.parse(map['status'] as String?),
        items: ((map['items'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MealItem.fromMap)
            .toList(),
      );
}

/// Non-food habits asked at the end of the check-in deck.
class DayHabits {
  const DayHabits({this.workout = false, this.waterGlasses = 0});

  final bool workout;
  final int waterGlasses;

  DayHabits copyWith({bool? workout, int? waterGlasses}) => DayHabits(
        workout: workout ?? this.workout,
        waterGlasses: waterGlasses ?? this.waterGlasses,
      );

  Map<String, dynamic> toMap() => {
        'workout': workout,
        'waterGlasses': waterGlasses,
      };

  factory DayHabits.fromMap(Map<String, dynamic>? map) => DayHabits(
        workout: (map?['workout'] as bool?) ?? false,
        waterGlasses: (map?['waterGlasses'] as num?)?.round() ?? 0,
      );
}

/// One document per day — `users/{uid}/days/{yyyy-MM-dd}`. Totals are stored
/// alongside the meals so a month view is 30 small reads and no maths on the
/// phone.
class DayLog {
  const DayLog({
    required this.date,
    this.meals = const [],
    this.habits = const DayHabits(),
    this.checkedInAt,
  });

  /// `yyyy-MM-dd`, and also the document id.
  final String date;
  final List<LoggedMeal> meals;
  final DayHabits habits;
  final DateTime? checkedInAt;

  bool get checkedIn => checkedInAt != null;

  double get kcal => meals.fold(0, (sum, meal) => sum + meal.kcal);
  double get proteinG => meals.fold(0, (sum, meal) => sum + meal.proteinG);
  double get carbsG => meals.fold(0, (sum, meal) => sum + meal.carbsG);
  double get fatG => meals.fold(0, (sum, meal) => sum + meal.fatG);

  /// Meals eaten in full or in part, out of those planned. Drives the
  /// consistency figure in History.
  int get mealsEaten =>
      meals.where((meal) => meal.status != MealStatus.skipped).length;

  Map<String, dynamic> toMap() => {
        'date': date,
        'meals': meals.map((meal) => meal.toMap()).toList(),
        'habits': habits.toMap(),
        'totals': {
          'kcal': kcal,
          'proteinG': proteinG,
          'carbsG': carbsG,
          'fatG': fatG,
        },
        'checkedInAt': checkedInAt?.toUtc().toIso8601String(),
      };

  factory DayLog.fromMap(String id, Map<String, dynamic> map) => DayLog(
        date: (map['date'] as String?) ?? id,
        meals: ((map['meals'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LoggedMeal.fromMap)
            .toList(),
        habits: DayHabits.fromMap(map['habits'] as Map<String, dynamic>?),
        checkedInAt: DateTime.tryParse((map['checkedInAt'] as String?) ?? ''),
      );
}

/// Consecutive days checked in, counting back from today. A missed day ends
/// the streak; today not being done yet does not.
int currentStreak(Iterable<DayLog> logs, {DateTime? now}) {
  final checked = {
    for (final log in logs.where((log) => log.checkedIn)) log.date,
  };
  if (checked.isEmpty) return 0;

  final today = now ?? DateTime.now();
  var cursor = DateTime(today.year, today.month, today.day);
  if (!checked.contains(dayId(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  var streak = 0;
  while (checked.contains(dayId(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
