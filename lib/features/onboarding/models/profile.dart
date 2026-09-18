import '../../../core/constants.dart';

/// The structured answers from the 6-screen quiz.
class Profile {
  const Profile({
    this.goal = Goal.maintain,
    this.sex = Sex.female,
    this.age = 30,
    this.heightCm = 170,
    this.weightKg = 70,
    this.activityLevel = ActivityLevel.moderate,
    this.dietType = DietType.omnivore,
    this.avoids = const [],
    this.mealsPerDay = 3,
    this.gymTime,
    this.mealTimes = const [],
  });

  final Goal goal;
  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final DietType dietType;

  /// Foods the user avoids, free text, e.g. `peanuts`, `dairy`.
  final List<String> avoids;
  final int mealsPerDay;

  /// `HH:mm` local time they usually train, or null if they don't.
  final String? gymTime;

  /// `HH:mm` local times they usually eat, in order.
  final List<String> mealTimes;

  Profile copyWith({
    Goal? goal,
    Sex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    DietType? dietType,
    List<String>? avoids,
    int? mealsPerDay,
    String? gymTime,
    List<String>? mealTimes,
  }) =>
      Profile(
        goal: goal ?? this.goal,
        sex: sex ?? this.sex,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        dietType: dietType ?? this.dietType,
        avoids: avoids ?? this.avoids,
        mealsPerDay: mealsPerDay ?? this.mealsPerDay,
        gymTime: gymTime ?? this.gymTime,
        mealTimes: mealTimes ?? this.mealTimes,
      );

  Map<String, dynamic> toMap() => {
        'goal': goal.name,
        'sex': sex.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel.name,
        'dietType': dietType.name,
        'avoids': avoids,
        'mealsPerDay': mealsPerDay,
        'gymTime': gymTime,
        'mealTimes': mealTimes,
      };

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        goal: Goal.parse(map['goal'] as String?),
        sex: Sex.parse(map['sex'] as String?),
        age: (map['age'] as num?)?.round() ?? 30,
        heightCm: (map['heightCm'] as num?)?.toDouble() ?? 170,
        weightKg: (map['weightKg'] as num?)?.toDouble() ?? 70,
        activityLevel: ActivityLevel.parse(map['activityLevel'] as String?),
        dietType: DietType.parse(map['dietType'] as String?),
        avoids: ((map['avoids'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(),
        mealsPerDay: (map['mealsPerDay'] as num?)?.round() ?? 3,
        gymTime: map['gymTime'] as String?,
        mealTimes: ((map['mealTimes'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(),
      );
}
