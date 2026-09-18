import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/demo_mode.dart';
import '../models/meal_item.dart';
import 'local_meal_parser.dart';

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

abstract class MealParserService {
  Future<ParseResult> parse(String text, {MealSlot? slot});
}

/// Calls the `parseMeal` Cloud Function. The Gemini key lives server-side, so
/// the app never holds it.
class RemoteMealParserService implements MealParserService {
  RemoteMealParserService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
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

/// Demo mode parses on-device, so the app needs no Gemini key to be shown.
/// The small delay stands in for a network round trip, which keeps the
/// loading states honest during a demo.
class LocalMealParserService implements MealParserService {
  @override
  Future<ParseResult> parse(String text, {MealSlot? slot}) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final result = parseMealLocally(text);
    return ParseResult(
      items: result.items,
      needsClarification: result.needsClarification,
      question: result.question,
    );
  }
}

final mealParserProvider = Provider<MealParserService>(
  (ref) => kDemoMode ? LocalMealParserService() : RemoteMealParserService(),
);
