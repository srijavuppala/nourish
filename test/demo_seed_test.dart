import 'package:flutter_test/flutter_test.dart';
import 'package:nourish/core/constants.dart';
import 'package:nourish/core/demo_store.dart';
import 'package:nourish/features/checkin/data/checkin_repository.dart';
import 'package:nourish/features/checkin/models/day_log.dart';
import 'package:nourish/features/demo/demo_seed.dart';
import 'package:nourish/features/onboarding/data/onboarding_repository.dart';
import 'package:nourish/features/plan/data/plan_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetCache();
  });

  test('seeds a full plan of four meals', () async {
    await seedDemoData();

    final meals = await DemoPlanRepository().loadMeals();
    expect(meals.length, 4);
    expect(meals.map((m) => m.slot), [
      MealSlot.breakfast,
      MealSlot.lunch,
      MealSlot.dinner,
      MealSlot.snack,
    ]);

    // The sample breakfast is the PRD's own example.
    final breakfast = meals.first;
    expect(breakfast.items.any((i) => i.name == 'Egg' && i.qty == 6), isTrue);
    expect(breakfast.items.any((i) => i.name == 'Banana' && i.qty == 2), isTrue);
  });

  test('every sample meal parses into something with real nutrition', () async {
    await seedDemoData();

    for (final meal in await DemoPlanRepository().loadMeals()) {
      expect(meal.items, isNotEmpty, reason: '${meal.label} parsed to nothing');
      expect(meal.kcal, greaterThan(0), reason: '${meal.label} has no calories');
      expect(meal.proteinG, greaterThan(0), reason: '${meal.label} has no protein');
    }
  });

  test('marks onboarding done so the demo lands on Today', () async {
    await seedDemoData();
    expect(await DemoOnboardingRepository().onboardingDone().first, isTrue);
  });

  test('sets targets the sample day can be measured against', () async {
    await seedDemoData();

    final targets = await DemoOnboardingRepository().watchTargets().first;
    expect(targets, isNotNull);
    expect(targets!.calories, greaterThan(2000));
    expect(targets.proteinG, greaterThan(100));
  });

  test('builds a fortnight of history with gaps, not a perfect run', () async {
    await seedDemoData();

    final now = DateTime.now();
    final logs = await DemoCheckinRepository()
        .watchRange(now.subtract(const Duration(days: 20)), now)
        .first;

    final checkedIn = logs.where((log) => log.checkedIn).toList();
    expect(checkedIn.length, 12);

    // Two deliberate gaps, so the grey "missed" styling is visible on screen.
    final dates = checkedIn.map((log) => log.date).toSet();
    expect(dates.contains(dayId(now.subtract(const Duration(days: 6)))), isFalse);
    expect(dates.contains(dayId(now.subtract(const Duration(days: 11)))), isFalse);
  });

  test('leaves today unfinished so the check-in button has work to do', () async {
    await seedDemoData();

    final today = await DemoCheckinRepository().loadDay(dayId(DateTime.now()));
    expect(today, isNotNull);
    expect(today!.checkedIn, isFalse);
    expect(today.mealsEaten, 2);
    expect(today.kcal, greaterThan(0));
  });

  test('yesterday is complete, so a streak shows on Today', () async {
    await seedDemoData();

    final now = DateTime.now();
    final logs = await DemoCheckinRepository()
        .watchRange(now.subtract(const Duration(days: 20)), now)
        .first;

    expect(currentStreak(logs, now: now), 5);
  });

  test('a seeded day totals the same as its plan meals', () async {
    await seedDemoData();

    final meals = await DemoPlanRepository().loadMeals();
    final yesterday = await DemoCheckinRepository()
        .loadDay(dayId(DateTime.now().subtract(const Duration(days: 1))));

    // Day 1 ate all four meals.
    final planTotal = meals.fold<double>(0, (sum, meal) => sum + meal.kcal);
    expect(yesterday!.kcal, closeTo(planTotal, 0.01));
  });

  test('is deterministic, so a demo shows the same numbers every time', () async {
    await seedDemoData();
    final first = (await DemoPlanRepository().loadMeals())
        .fold<double>(0, (sum, meal) => sum + meal.kcal);

    SharedPreferences.setMockInitialValues({});
    await seedDemoData();
    final second = (await DemoPlanRepository().loadMeals())
        .fold<double>(0, (sum, meal) => sum + meal.kcal);

    expect(second, first);
  });
}
