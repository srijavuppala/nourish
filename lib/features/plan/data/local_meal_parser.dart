import '../models/meal_item.dart';

/// A small nutrition table for demo mode. Values are per one [unit] of the
/// food, taken from typical USDA figures.
class _Food {
  const _Food(
    this.name,
    this.unit,
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG, {
    this.aliases = const [],
  });

  final String name;
  final String unit;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final List<String> aliases;
}

const _foods = <_Food>[
  _Food('Egg', 'large', 72, 6.3, 0.4, 4.8, aliases: ['eggs']),
  _Food('Banana', 'medium', 105, 1.3, 27, 0.4, aliases: ['bananas']),
  _Food('Apple', 'medium', 95, 0.5, 25, 0.3, aliases: ['apples']),
  _Food('Orange', 'medium', 62, 1.2, 15.4, 0.2, aliases: ['oranges']),
  _Food('Bread', 'slice', 79, 3.1, 14.7, 1,
      aliases: ['toast', 'slices of bread', 'slice of bread'],),
  _Food('Oats', 'g', 3.89, 0.169, 0.663, 0.069,
      aliases: ['oatmeal', 'porridge'],),
  _Food('Rice', 'cup', 206, 4.3, 45, 0.4, aliases: ['white rice']),
  _Food('Chicken breast', 'g', 1.65, 0.31, 0, 0.036,
      aliases: ['chicken'],),
  _Food('Salmon', 'g', 2.08, 0.2, 0, 0.13),
  _Food('Milk', 'cup', 149, 7.7, 11.7, 8),
  _Food('Yogurt', 'cup', 149, 8.5, 11.4, 8, aliases: ['curd', 'yoghurt']),
  _Food('Peanut butter', 'tbsp', 94, 4, 3.6, 8),
  _Food('Protein shake', 'scoop', 120, 24, 3, 1.5,
      aliases: ['protein', 'whey', 'protein powder'],),
  _Food('Coffee', 'cup', 2, 0.3, 0, 0),
  _Food('Potato', 'medium', 161, 4.3, 37, 0.2, aliases: ['potatoes']),
  _Food('Almonds', 'g', 5.79, 0.212, 0.216, 0.499, aliases: ['almond']),
  _Food('Dal', 'cup', 230, 18, 40, 0.8, aliases: ['lentils', 'daal']),
  _Food('Roti', 'piece', 120, 3, 18, 3.7,
      aliases: ['chapati', 'chapatti', 'rotis'],),
  _Food('Paneer', 'g', 2.65, 0.18, 0.012, 0.21),
  _Food('Rajma', 'cup', 215, 13, 40, 0.9, aliases: ['kidney beans']),
  _Food('Idli', 'piece', 58, 1.6, 12, 0.4, aliases: ['idlis']),
  _Food('Dosa', 'piece', 133, 2.7, 17, 6, aliases: ['dosas']),
  _Food('Curd rice', 'cup', 250, 7, 42, 6),
  _Food('Tofu', 'g', 0.76, 0.081, 0.019, 0.048),
  _Food('Paratha', 'piece', 260, 5, 32, 12, aliases: ['parathas']),
];

const _numberWords = <String, double>{
  'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
  'twelve': 12, 'half': 0.5, 'couple': 2, 'dozen': 12,
};

/// Foods measured in grams default to a sensible serving when the user gives
/// no amount, so "chicken and rice" still produces usable numbers.
const _defaultGrams = <String, double>{
  'Oats': 60,
  'Chicken breast': 150,
  'Salmon': 120,
  'Almonds': 30,
  'Paneer': 100,
  'Tofu': 100,
};

/// Result shape mirrors the Cloud Function, so the UI cannot tell them apart.
class LocalParseResult {
  const LocalParseResult({
    required this.items,
    this.needsClarification = false,
    this.question = '',
  });

  final List<MealItem> items;
  final bool needsClarification;
  final String question;
}

/// A rule-based parser used only in demo mode, where no Gemini key exists.
///
/// It handles the shapes people actually type — "six eggs and two bananas",
/// "2 rotis with dal", "100g chicken" — and asks a question when it finds
/// nothing it recognises, exactly as the real parser does.
LocalParseResult parseMealLocally(String text) {
  final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s./]'), ' ');
  final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  final items = <MealItem>[];
  final matched = <String>{};

  for (var index = 0; index < tokens.length; index++) {
    final food = _matchFoodAt(tokens, index);
    if (food == null) continue;
    if (matched.contains(food.food.name)) continue;

    final quantity = _quantityBefore(tokens, index);
    final grams = _gramsBefore(tokens, index);

    double qty;
    if (food.food.unit == 'g') {
      // Weighed foods: use the stated grams, else a typical serving.
      qty = grams ?? _defaultGrams[food.food.name] ?? 100;
    } else {
      qty = quantity ?? 1;
    }

    matched.add(food.food.name);
    items.add(
      MealItem(
        name: food.food.name,
        qty: qty,
        unit: food.food.unit,
        kcal: food.food.kcal * qty,
        proteinG: food.food.proteinG * qty,
        carbsG: food.food.carbsG * qty,
        fatG: food.food.fatG * qty,
      ),
    );

    index += food.length - 1;
  }

  if (items.isEmpty) {
    return const LocalParseResult(
      items: [],
      needsClarification: true,
      question: "I don't know that one yet. Try something like "
          '"six eggs and two bananas".',
    );
  }

  return LocalParseResult(items: items);
}

class _Match {
  const _Match(this.food, this.length);
  final _Food food;
  final int length;
}

/// Matches the longest food name starting at [index], so "chicken breast"
/// wins over "chicken".
_Match? _matchFoodAt(List<String> tokens, int index) {
  _Match? best;

  for (final food in _foods) {
    for (final candidate in [food.name.toLowerCase(), ...food.aliases]) {
      final words = candidate.split(' ');
      if (index + words.length > tokens.length) continue;

      var hit = true;
      for (var offset = 0; offset < words.length; offset++) {
        if (tokens[index + offset] != words[offset]) {
          hit = false;
          break;
        }
      }
      if (!hit) continue;

      if (best == null || words.length > best.length) {
        best = _Match(food, words.length);
      }
    }
  }

  return best;
}

/// The number immediately before a food word: "six eggs", "2 rotis".
double? _quantityBefore(List<String> tokens, int index) {
  if (index == 0) return null;
  final previous = tokens[index - 1];

  final word = _numberWords[previous];
  if (word != null) return word;

  final digits = double.tryParse(previous);
  if (digits != null && digits > 0 && digits < 1000) return digits;

  return null;
}

/// A gram or millilitre amount before a food: "100g chicken", "200 g paneer".
double? _gramsBefore(List<String> tokens, int index) {
  for (var back = 1; back <= 2 && index - back >= 0; back++) {
    final token = tokens[index - back];

    final combined = RegExp(r'^(\d+(?:\.\d+)?)(g|ml|gm|gms|grams?)$').firstMatch(token);
    if (combined != null) return double.tryParse(combined.group(1)!);

    if (['g', 'gm', 'gms', 'gram', 'grams', 'ml'].contains(token) &&
        index - back - 1 >= 0) {
      final amount = double.tryParse(tokens[index - back - 1]);
      if (amount != null) return amount;
    }
  }
  return null;
}
