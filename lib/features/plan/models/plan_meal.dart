import '../../../core/constants.dart';
import 'meal_item.dart';

/// A meal the user told us they normally eat. This is the template the daily
/// check-in generates its cards from.
class PlanMeal {
  const PlanMeal({
    required this.id,
    required this.slot,
    required this.label,
    required this.items,
    this.source = 'chat',
  });

  final String id;
  final MealSlot slot;

  /// What the user calls it, e.g. `Usual breakfast`.
  final String label;
  final List<MealItem> items;

  /// `chat` when the AI parsed it, `manual` when typed in My Plan.
  final String source;

  double get kcal => items.fold(0, (sum, item) => sum + item.kcal);
  double get proteinG => items.fold(0, (sum, item) => sum + item.proteinG);
  double get carbsG => items.fold(0, (sum, item) => sum + item.carbsG);
  double get fatG => items.fold(0, (sum, item) => sum + item.fatG);

  /// `6 large Egg + 2 medium Banana` — the question on a check-in card.
  String get summary => items.map((item) => item.display).join(' + ');

  PlanMeal copyWith({
    MealSlot? slot,
    String? label,
    List<MealItem>? items,
    String? source,
  }) =>
      PlanMeal(
        id: id,
        slot: slot ?? this.slot,
        label: label ?? this.label,
        items: items ?? this.items,
        source: source ?? this.source,
      );

  Map<String, dynamic> toMap() => {
        'slot': slot.name,
        'label': label,
        'items': items.map((item) => item.toMap()).toList(),
        'source': source,
      };

  factory PlanMeal.fromMap(String id, Map<String, dynamic> map) => PlanMeal(
        id: id,
        slot: MealSlot.parse(map['slot'] as String?),
        label: (map['label'] as String?) ?? '',
        items: ((map['items'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MealItem.fromMap)
            .toList(),
        source: (map['source'] as String?) ?? 'chat',
      );
}
