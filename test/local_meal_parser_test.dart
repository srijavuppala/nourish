import 'package:flutter_test/flutter_test.dart';
import 'package:nourish/features/plan/data/local_meal_parser.dart';

void main() {
  group('parseMealLocally', () {
    test('parses the PRD example', () {
      final result = parseMealLocally('six eggs and two bananas');

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Egg');
      expect(result.items[0].qty, 6);
      expect(result.items[0].kcal, closeTo(432, 1));
      expect(result.items[1].name, 'Banana');
      expect(result.items[1].qty, 2);
    });

    test('reads digits as well as number words', () {
      final result = parseMealLocally('2 rotis with dal');
      expect(result.items.firstWhere((i) => i.name == 'Roti').qty, 2);
      expect(result.items.any((i) => i.name == 'Dal'), isTrue);
    });

    test('handles a gram amount written either way', () {
      expect(parseMealLocally('100g chicken').items.single.qty, 100);
      expect(parseMealLocally('200 g paneer').items.single.qty, 200);
    });

    test('falls back to a sensible serving for weighed foods', () {
      final result = parseMealLocally('oats with milk');
      expect(result.items.firstWhere((i) => i.name == 'Oats').qty, 60);
    });

    test('prefers the longer food name', () {
      final result = parseMealLocally('150g chicken breast');
      expect(result.items.single.name, 'Chicken breast');
    });

    test('defaults to one when no amount is given', () {
      expect(parseMealLocally('an apple').items.single.qty, 1);
    });

    test('scales nutrition with the quantity', () {
      final one = parseMealLocally('one egg').items.single;
      final six = parseMealLocally('six eggs').items.single;
      expect(six.kcal, closeTo(one.kcal * 6, 0.01));
      expect(six.proteinG, closeTo(one.proteinG * 6, 0.01));
    });

    test('ignores punctuation and casing', () {
      final result = parseMealLocally('Six Eggs, Two Bananas!');
      expect(result.items.length, 2);
    });

    test('does not list the same food twice', () {
      final result = parseMealLocally('eggs and more eggs');
      expect(result.items.length, 1);
    });

    test('asks a question when it recognises nothing', () {
      final result = parseMealLocally('the usual thing');
      expect(result.items, isEmpty);
      expect(result.needsClarification, isTrue);
      expect(result.question, contains('six eggs'));
    });

    test('handles Indian foods in the table', () {
      final result = parseMealLocally('3 idlis and a dosa');
      expect(result.items.firstWhere((i) => i.name == 'Idli').qty, 3);
      expect(result.items.any((i) => i.name == 'Dosa'), isTrue);
    });
  });
}
