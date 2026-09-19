import '../../core/constants.dart';
import '../../core/demo_store.dart';
import '../checkin/data/checkin_repository.dart';
import '../checkin/models/day_log.dart';
import '../onboarding/data/onboarding_repository.dart';
import '../onboarding/data/targets_calculator.dart';
import '../onboarding/models/profile.dart';
import '../plan/data/local_meal_parser.dart';
import '../plan/data/plan_repository.dart';
import '../plan/models/meal_item.dart';
import '../plan/models/plan_meal.dart';

/// Sample data for demo mode, so the app can be shown with a filled-in
/// dashboard and a real history rather than empty rings.
///
/// Everything is deterministic: the same demo produces the same numbers every
/// time, which matters when you are presenting it.

/// A gym-goer tracking protein — the persona the check-in is built for.
/// The goal and weight are chosen so the sample plan lands near the targets
/// it produces; a demo where the plan is 150% of target looks broken.
const _demoProfile = Profile(
  goal: Goal.buildMuscle,
  sex: Sex.male,
  age: 28,
  heightCm: 178,
  weightKg: 82,
  activityLevel: ActivityLevel.moderate,
  mealsPerDay: 4,
  gymTime: '07:00',
  mealTimes: ['08:00', '13:00', '19:30'],
);

/// The meals are written as sentences and run through the same parser the app
/// uses, so the sample plan cannot drift from what the parser actually
/// produces.
const _demoMeals = <(MealSlot, String, String)>[
  (MealSlot.breakfast, 'Usual breakfast', 'six eggs and two bananas and 60g oats'),
  (MealSlot.lunch, 'Usual lunch', '3 rotis with dal and 100g paneer'),
  (MealSlot.dinner, 'Usual dinner', '200g chicken breast and 2 cups rice'),
  (MealSlot.snack, 'After the gym', 'a protein shake and 30g almonds'),
];

/// How the last fortnight went, most recent first. Each entry says which of
/// the four meals were eaten, and whether they trained.
///
/// Deliberately imperfect: two days with no check-in at all, several with a
/// meal skipped. A demo of a perfect streak is not believable, and the grey
/// "missed" styling never gets shown.
const _history = <({int daysAgo, List<int> ate, bool workout, int water})>[
  (daysAgo: 1, ate: [0, 1, 2, 3], workout: true, water: 8),
  (daysAgo: 2, ate: [0, 1, 2], workout: true, water: 6),
  (daysAgo: 3, ate: [0, 1, 2, 3], workout: false, water: 7),
  (daysAgo: 4, ate: [0, 2, 3], workout: true, water: 5),
  (daysAgo: 5, ate: [0, 1, 2, 3], workout: true, water: 9),
  // Day 6 missing on purpose.
  (daysAgo: 7, ate: [0, 1], workout: false, water: 4),
  (daysAgo: 8, ate: [0, 1, 2, 3], workout: true, water: 8),
  (daysAgo: 9, ate: [0, 1, 2], workout: true, water: 6),
  (daysAgo: 10, ate: [0, 1, 2, 3], workout: false, water: 7),
  // Day 11 missing on purpose.
  (daysAgo: 12, ate: [0, 2], workout: true, water: 5),
  (daysAgo: 13, ate: [0, 1, 2, 3], workout: true, water: 8),
  (daysAgo: 14, ate: [0, 1, 2], workout: false, water: 6),
];

/// Today is left half done, so the check-in button has something to do and the
/// rings are partly filled — which is what you want on screen when demoing.
const _todayAte = [0, 1];

List<MealItem> _itemsFor(String sentence) => parseMealLocally(sentence).items;

/// Writes the sample profile, plan and history. Demo repositories take no
/// arguments, so this builds its own and needs no provider scope.
Future<void> seedDemoData() async {
  // Start clean, so seeding twice replaces the sample data rather than
  // stacking a second copy of every meal on top of the first.
  await (await DemoStore.instance()).clear();

  final onboarding = DemoOnboardingRepository();
  final plan = DemoPlanRepository();
  final checkin = DemoCheckinRepository();

  await onboarding.saveProfile(_demoProfile);
  await onboarding.saveTargets(TargetsCalculator.fromProfile(_demoProfile));

  final planMeals = <PlanMeal>[];
  for (final (slot, label, sentence) in _demoMeals) {
    final items = _itemsFor(sentence);
    final id = await plan.addMeal(slot: slot, label: label, items: items);
    planMeals.add(
      PlanMeal(id: id, slot: slot, label: label, items: items, source: 'chat'),
    );
  }

  final today = DateTime.now();
  for (final day in _history) {
    final date = today.subtract(Duration(days: day.daysAgo));
    await checkin.saveDay(
      _dayLog(
        date: date,
        planMeals: planMeals,
        ateIndexes: day.ate,
        workout: day.workout,
        water: day.water,
        // Evening check-in, roughly when the reminder fires.
        checkedInAt: DateTime(date.year, date.month, date.day, 20, 15),
      ),
    );
  }

  await checkin.saveDay(
    _dayLog(
      date: today,
      planMeals: planMeals,
      ateIndexes: _todayAte,
      workout: true,
      water: 4,
      checkedInAt: null,
    ),
  );

  await onboarding.markOnboardingDone();
}

DayLog _dayLog({
  required DateTime date,
  required List<PlanMeal> planMeals,
  required List<int> ateIndexes,
  required bool workout,
  required int water,
  required DateTime? checkedInAt,
}) =>
    DayLog(
      date: dayId(date),
      meals: [
        for (var index = 0; index < planMeals.length; index++)
          LoggedMeal(
            mealId: planMeals[index].id,
            slot: planMeals[index].slot,
            label: planMeals[index].label,
            status: ateIndexes.contains(index)
                ? MealStatus.ate
                : MealStatus.skipped,
            items: ateIndexes.contains(index) ? planMeals[index].items : const [],
          ),
      ],
      habits: DayHabits(workout: workout, waterGlasses: water),
      checkedInAt: checkedInAt,
    );
