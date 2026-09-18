import 'dart:math' as math;

/// One food in a meal, e.g. `6 large Egg`. Nutrition is stored for the whole
/// [qty], not per unit, so totalling a meal is a plain sum.
class MealItem {
  const MealItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.kcal,
    required this.proteinG,
    this.carbsG = 0,
    this.fatG = 0,
  });

  final String name;
  final double qty;
  final String unit;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  /// The same food at a different quantity, with nutrition scaled to match.
  /// This is what the check-in stepper uses when someone ate 3 of 6 eggs.
  MealItem withQty(double newQty) {
    if (qty <= 0) return copyWith(qty: math.max(newQty, 0));
    final factor = math.max(newQty, 0) / qty;
    return MealItem(
      name: name,
      qty: math.max(newQty, 0),
      unit: unit,
      kcal: kcal * factor,
      proteinG: proteinG * factor,
      carbsG: carbsG * factor,
      fatG: fatG * factor,
    );
  }

  MealItem copyWith({
    String? name,
    double? qty,
    String? unit,
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) =>
      MealItem(
        name: name ?? this.name,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        kcal: kcal ?? this.kcal,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
      );

  /// Units that are a measure rather than a description, so they read better
  /// attached to the number: `60g Oats`, not `60 g Oats`.
  static const _attachedUnits = {'g', 'kg', 'ml', 'l', 'oz', 'lb'};

  /// Units that add nothing once the food is named. `3 Roti` says everything
  /// `3 piece Roti` does.
  static const _silentUnits = {'piece', 'pieces', 'item', 'items', 'unit'};

  /// `6 large Egg`, `60g Oats`, `3 Roti` — what the cards and plan rows show.
  String get display {
    final quantity = qty == qty.roundToDouble()
        ? qty.round().toString()
        : qty.toStringAsFixed(1);

    final cleanUnit = unit.trim().toLowerCase();
    if (cleanUnit.isEmpty || _silentUnits.contains(cleanUnit)) {
      return '$quantity $name';
    }
    if (_attachedUnits.contains(cleanUnit)) {
      return '$quantity$cleanUnit $name';
    }
    return '$quantity ${unit.trim()} $name';
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'qty': qty,
        'unit': unit,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };

  /// Tolerant on purpose: this parses both Firestore documents and the JSON
  /// the `parseMeal` function returns, where a field may be missing.
  factory MealItem.fromMap(Map<String, dynamic> map) => MealItem(
        name: (map['name'] as String?)?.trim().isNotEmpty == true
            ? (map['name'] as String).trim()
            : 'Item',
        qty: _toDouble(map['qty'], fallback: 1),
        unit: (map['unit'] as String?)?.trim() ?? '',
        kcal: _toDouble(map['kcal']),
        proteinG: _toDouble(map['proteinG']),
        carbsG: _toDouble(map['carbsG']),
        fatG: _toDouble(map['fatG']),
      );

  static double _toDouble(Object? value, {double fallback = 0}) {
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite && result >= 0 ? result : fallback;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite && parsed >= 0) return parsed;
    }
    return fallback;
  }
}
