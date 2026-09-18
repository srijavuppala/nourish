import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../models/meal_item.dart';

/// What the parser understood from one sentence.
class ParseResult {
  const ParseResult({
    required this.items,
    this.needsClarification = false,
    this.question = '',
  });

  final List<MealItem> items;

  /// True when the parser wants one more detail before this meal is complete.
  final bool needsClarification;
  final String question;

  bool get isEmpty => items.isEmpty;
}

/// Raised for a failure worth showing the user, with a message safe to display.
class MealParseException implements Exception {
  MealParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Calls the `parseMeal` Cloud Function. The Gemini key lives server-side, so
/// the app never holds it.
class MealParserService {
  MealParserService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<ParseResult> parse(String text, {MealSlot? slot}) async {
    try {
      final callable = _functions.httpsCallable('parseMealCallable');
      final response = await callable.call<Map<String, dynamic>>({
        'text': text,
        'slot': slot?.name,
      });

      final data = response.data;
      final items = ((data['items'] as List<dynamic>?) ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map((raw) => MealItem.fromMap(Map<String, dynamic>.from(raw)))
          .toList();

      return ParseResult(
        items: items,
        needsClarification: data['needsClarification'] == true,
        question: (data['question'] as String?) ?? '',
      );
    } on FirebaseFunctionsException catch (error) {
      // `invalid-argument` messages are written for the user; the rest are not.
      throw MealParseException(
        error.code == 'invalid-argument' && (error.message?.isNotEmpty ?? false)
            ? error.message!
            : "I couldn't read that just now. Try again in a moment.",
      );
    } catch (_) {
      throw MealParseException(
        'No connection. Your meal will be here when you are back online.',
      );
    }
  }
}

final mealParserProvider = Provider<MealParserService>(
  (ref) => MealParserService(),
);
