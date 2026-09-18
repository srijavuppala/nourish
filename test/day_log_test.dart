import 'package:flutter_test/flutter_test.dart';
import 'package:nourish/core/constants.dart';
import 'package:nourish/features/checkin/models/day_log.dart';
import 'package:nourish/features/plan/models/meal_item.dart';

const _egg = MealItem(
  name: 'Egg',
  qty: 6,
  unit: 'large',
  kcal: 432,
  proteinG: 36,
  carbsG: 2.4,
  fatG: 30,
);

DayLog _log(String date, {bool checkedIn = true}) => DayLog(
      date: date,
      meals: [
        const LoggedMeal(
          mealId: 'breakfast',
          slot: MealSlot.breakfast,
          label: 'Usual breakfast',
          status: MealStatus.ate,
          items: [_egg],
        ),
      ],
      checkedInAt: checkedIn ? DateTime.parse('${date}T20:00:00Z') : null,
    );

void main() {
  group('MealItem.withQty', () {
    test('scales nutrition proportionally', () {
      final half = _egg.withQty(3);
      expect(half.qty, 3);
      expect(half.kcal, 216);
      expect(half.proteinG, 18);
    });

    test('going to zero zeroes the nutrition', () {
      final none = _egg.withQty(0);
      expect(none.qty, 0);
      expect(none.kcal, 0);
    });

    test('never produces a negative quantity', () {
      expect(_egg.withQty(-5).qty, 0);
    });

    test('formats a whole quantity without a decimal point', () {
      expect(_egg.display, '6 large Egg');
      expect(_egg.withQty(2.5).display, '2.5 large Egg');
    });
  });

  group('MealItem.display', () {
    MealItem withUnit(String unit) => MealItem(
          name: 'Oats',
          qty: 60,
          unit: unit,
          kcal: 233,
          proteinG: 10,
        );

    test('attaches mass and volume units to the number', () {
      expect(withUnit('g').display, '60g Oats');
      expect(withUnit('ml').display, '60ml Oats');
      expect(withUnit('G').display, '60g Oats');
    });

    test('keeps descriptive units as separate words', () {
      expect(_egg.display, '6 large Egg');
      expect(
        const MealItem(name: 'Dal', qty: 1, unit: 'cup', kcal: 230, proteinG: 18)
            .display,
        '1 cup Dal',
      );
    });

    test('drops units that add nothing to the name', () {
      expect(
        const MealItem(name: 'Roti', qty: 3, unit: 'piece', kcal: 360, proteinG: 9)
            .display,
        '3 Roti',
      );
    });

    test('handles a missing unit', () {
      expect(
        const MealItem(name: 'Apple', qty: 2, unit: '', kcal: 190, proteinG: 1)
            .display,
        '2 Apple',
      );
    });
  });

  group('DayLog totals', () {
    test('sums the meals that were eaten', () {
      final log = _log('2026-09-17');
      expect(log.kcal, 432);
      expect(log.proteinG, 36);
      expect(log.mealsEaten, 1);
    });

    test('a skipped meal contributes nothing', () {
      const log = DayLog(
        date: '2026-09-17',
        meals: [
          LoggedMeal(
            mealId: 'breakfast',
            slot: MealSlot.breakfast,
            label: 'Usual breakfast',
            status: MealStatus.skipped,
            items: [],
          ),
        ],
      );
      expect(log.kcal, 0);
      expect(log.mealsEaten, 0);
    });

    test('survives a round trip through Firestore', () {
      final original = _log('2026-09-17');
      final restored = DayLog.fromMap('2026-09-17', original.toMap());

      expect(restored.date, original.date);
      expect(restored.kcal, original.kcal);
      expect(restored.meals.single.status, MealStatus.ate);
      expect(restored.checkedIn, isTrue);
    });
  });

  group('currentStreak', () {
    final now = DateTime(2026, 9, 17);

    test('counts consecutive days back from today', () {
      final logs = [
        _log('2026-09-17'),
        _log('2026-09-16'),
        _log('2026-09-15'),
      ];
      expect(currentStreak(logs, now: now), 3);
    });

    test('a gap ends the streak', () {
      final logs = [
        _log('2026-09-17'),
        _log('2026-09-16'),
        // 15th missing
        _log('2026-09-14'),
      ];
      expect(currentStreak(logs, now: now), 2);
    });

    test('today not yet done does not break yesterday-onward streak', () {
      final logs = [_log('2026-09-16'), _log('2026-09-15')];
      expect(currentStreak(logs, now: now), 2);
    });

    test('days without a check-in do not count', () {
      final logs = [_log('2026-09-17', checkedIn: false)];
      expect(currentStreak(logs, now: now), 0);
    });

    test('no history is a zero streak', () {
      expect(currentStreak(const [], now: now), 0);
    });
  });

  group('dayId', () {
    test('zero-pads month and day', () {
      expect(dayId(DateTime(2026, 1, 5)), '2026-01-05');
      expect(dayId(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
