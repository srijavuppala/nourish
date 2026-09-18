/// Daily calorie and macro goals. Calculated once from the quiz, then editable
/// in Profile — so [explanation] records how the first version was reached.
class Targets {
  const Targets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.explanation = '',
    this.updatedAt,
  });

  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String explanation;
  final DateTime? updatedAt;

  Targets copyWith({
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    String? explanation,
    DateTime? updatedAt,
  }) =>
      Targets(
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        explanation: explanation ?? this.explanation,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'explanation': explanation,
        'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  factory Targets.fromMap(Map<String, dynamic> map) => Targets(
        calories: (map['calories'] as num?)?.round() ?? 2000,
        proteinG: (map['proteinG'] as num?)?.round() ?? 120,
        carbsG: (map['carbsG'] as num?)?.round() ?? 200,
        fatG: (map['fatG'] as num?)?.round() ?? 60,
        explanation: (map['explanation'] as String?) ?? '',
        updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? ''),
      );
}
