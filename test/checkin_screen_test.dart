import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nourish/core/constants.dart';
import 'package:nourish/features/checkin/data/checkin_repository.dart';
import 'package:nourish/features/checkin/models/day_log.dart';
import 'package:nourish/features/checkin/screens/checkin_screen.dart';
import 'package:nourish/features/plan/data/plan_repository.dart';
import 'package:nourish/features/plan/models/meal_item.dart';
import 'package:nourish/features/plan/models/plan_meal.dart';

/// Captures whatever the screen saves, so the test can assert on the day
/// document rather than on pixels.
class _CapturingCheckinRepository implements CheckinRepository {
  DayLog? saved;

  @override
  Future<void> saveDay(DayLog log) async => saved = log;

  @override
  Stream<DayLog?> watchDay(String date) => Stream.value(null);

  @override
  Future<DayLog?> loadDay(String date) async => null;

  @override
  Stream<List<DayLog>> watchRange(DateTime from, DateTime to) =>
      Stream.value(const []);
}

const _breakfast = PlanMeal(
  id: 'b1',
  slot: MealSlot.breakfast,
  label: 'Usual breakfast',
  items: [
    MealItem(
      name: 'Egg',
      qty: 6,
      unit: 'large',
      kcal: 432,
      proteinG: 36,
      carbsG: 2.4,
      fatG: 30,
    ),
  ],
);

const _lunch = PlanMeal(
  id: 'l1',
  slot: MealSlot.lunch,
  label: 'Usual lunch',
  items: [
    MealItem(
      name: 'Dal',
      qty: 1,
      unit: 'cup',
      kcal: 230,
      proteinG: 18,
      carbsG: 40,
      fatG: 0.8,
    ),
  ],
);

Widget _app(
  List<PlanMeal> meals,
  _CapturingCheckinRepository repository,
) {
  final router = GoRouter(
    initialLocation: '/checkin',
    routes: [
      GoRoute(path: '/checkin', builder: (_, __) => const CheckinScreen()),
      GoRoute(
        path: '/today',
        builder: (_, __) => const Scaffold(body: Text('today')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      planMealsProvider.overrideWith((ref) => Stream.value(meals)),
      checkinRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('empty plan explains what to do instead of showing a deck',
      (tester) async {
    await tester.pumpWidget(_app(const [], _CapturingCheckinRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No meals in your plan yet'), findsOneWidget);
    expect(find.text('Yes'), findsNothing);
  });

  testWidgets('builds a card from the user\'s own plan', (tester) async {
    await tester.pumpWidget(
      _app(const [_breakfast], _CapturingCheckinRepository()),
    );
    await tester.pumpAndSettle();

    // The question is the meal itself, in the user's words.
    expect(find.text('6 large Egg'), findsWidgets);
    expect(find.text('Did you have this?'), findsOneWidget);
    expect(find.text('BREAKFAST'), findsOneWidget);
  });

  testWidgets('answering yes to everything records both meals as eaten',
      (tester) async {
    final repository = _CapturingCheckinRepository();
    await tester.pumpWidget(_app(const [_breakfast, _lunch], repository));
    await tester.pumpAndSettle();

    // Two meals, then the workout card and the water card.
    for (var card = 0; card < 4; card++) {
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
    }

    expect(find.text('That is today done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final saved = repository.saved;
    expect(saved, isNotNull);
    expect(saved!.meals.length, 2);
    expect(saved.meals.every((m) => m.status == MealStatus.ate), isTrue);
    expect(saved.kcal, 662); // 432 + 230
    expect(saved.proteinG, 54); // 36 + 18
    expect(saved.habits.workout, isTrue);
    expect(saved.checkedIn, isTrue);
  });

  testWidgets('answering no records the meal as skipped with no nutrition',
      (tester) async {
    final repository = _CapturingCheckinRepository();
    await tester.pumpWidget(_app(const [_breakfast], repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    for (var card = 0; card < 2; card++) {
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final saved = repository.saved!;
    expect(saved.meals.single.status, MealStatus.skipped);
    expect(saved.meals.single.items, isEmpty);
    expect(saved.kcal, 0);
  });

  testWidgets('the stepper scales a partial portion and marks it partial',
      (tester) async {
    final repository = _CapturingCheckinRepository();
    await tester.pumpWidget(_app(const [_breakfast], repository));
    await tester.pumpAndSettle();

    // "Only 3 eggs": tap minus three times on the card's stepper.
    for (var tap = 0; tap < 3; tap++) {
      await tester.tap(find.byTooltip('Less Egg').first);
      await tester.pumpAndSettle();
    }
    expect(find.text('3 large Egg'), findsWidgets);

    for (var card = 0; card < 3; card++) {
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final saved = repository.saved!;
    expect(saved.meals.single.status, MealStatus.partial);
    expect(saved.meals.single.items.single.qty, 3);
    expect(saved.kcal, 216); // half of 432
  });
}
