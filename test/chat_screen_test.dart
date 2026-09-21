import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nourish/core/app_user.dart';
import 'package:nourish/core/constants.dart';
import 'package:nourish/features/auth/data/auth_repository.dart';
import 'package:nourish/features/notifications/notification_service.dart';
import 'package:nourish/features/onboarding/data/onboarding_repository.dart';
import 'package:nourish/features/onboarding/models/profile.dart';
import 'package:nourish/features/onboarding/models/targets.dart';
import 'package:nourish/features/onboarding/screens/chat_screen.dart';
import 'package:nourish/features/plan/data/meal_parser_service.dart';
import 'package:nourish/features/plan/data/plan_repository.dart';
import 'package:nourish/features/plan/models/meal_item.dart';
import 'package:nourish/features/plan/models/plan_meal.dart';

/// A parser whose answer each test decides, so the chat can be driven through
/// its success, clarification and failure paths without a network.
class _StubParser implements MealParserService {
  _StubParser(this.respond);

  final ParseResult Function(String text, MealSlot? slot) respond;
  final List<({String text, MealSlot? slot})> calls = [];

  @override
  Future<ParseResult> parse(String text, {MealSlot? slot}) async {
    calls.add((text: text, slot: slot));
    return respond(text, slot);
  }
}

class _ThrowingParser implements MealParserService {
  @override
  Future<ParseResult> parse(String text, {MealSlot? slot}) async =>
      throw MealParseException('No connection.');
}

class _RecordingPlanRepository implements PlanRepository {
  final List<PlanMeal> saved = [];

  @override
  Future<String> addMeal({
    required MealSlot slot,
    required String label,
    required List<MealItem> items,
    String source = 'chat',
  }) async {
    final id = 'meal-${saved.length}';
    saved.add(
      PlanMeal(id: id, slot: slot, label: label, items: items, source: source),
    );
    return id;
  }

  @override
  Stream<List<PlanMeal>> watchMeals() => Stream.value(saved);
  @override
  Future<List<PlanMeal>> loadMeals() async => saved;
  @override
  Future<void> updateMeal(PlanMeal meal) async {}
  @override
  Future<void> deleteMeal(String mealId) async {}
}

class _FakeOnboardingRepository implements OnboardingRepository {
  bool done = false;

  @override
  Future<void> markOnboardingDone() async => done = true;
  @override
  Future<Profile?> loadProfile() async => const Profile(gymTime: '06:30');
  @override
  Future<void> ensureUserDocument(AppUser user) async {}
  @override
  Stream<bool> onboardingDone() => Stream.value(done);
  @override
  Future<void> saveProfile(Profile profile) async {}
  @override
  Stream<Targets?> watchTargets() => Stream.value(null);
  @override
  Future<void> saveTargets(Targets targets) async {}
  @override
  Future<void> appendChatMessage({
    required String role,
    required String text,
    List<Map<String, dynamic>>? parsedItems,
  }) async {}
}

/// Avoids the platform plugin, and records what the chat asked it to schedule.
class _FakeNotificationService implements NotificationService {
  Reminder? morning;
  Reminder? evening;
  bool permissionsGranted = true;

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<void> scheduleDaily({
    required Reminder morning,
    required Reminder evening,
  }) async {
    this.morning = morning;
    this.evening = evening;
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<({Reminder evening, bool enabled, Reminder morning})>
      loadSettings() async =>
          (morning: defaultMorning, evening: defaultEvening, enabled: false);
}

const _eggs = MealItem(
  name: 'Egg',
  qty: 6,
  unit: 'large',
  kcal: 432,
  proteinG: 36,
  carbsG: 2.4,
  fatG: 30,
);

ParseResult _ok() => const ParseResult(items: [_eggs]);

Widget _app({
  required MealParserService parser,
  required _RecordingPlanRepository plan,
  required _FakeOnboardingRepository onboarding,
  required _FakeNotificationService notifications,
}) {
  final router = GoRouter(
    initialLocation: '/onboarding/chat',
    routes: [
      GoRoute(
        path: '/onboarding/chat',
        builder: (_, __) => const ChatScreen(),
      ),
      GoRoute(
        path: '/today',
        builder: (_, __) => const Scaffold(body: Text('today screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(uid: 'u1')),
      ),
      mealParserProvider.overrideWithValue(parser),
      planRepositoryProvider.overrideWithValue(plan),
      onboardingRepositoryProvider.overrideWithValue(onboarding),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Types into the chat box and submits.
Future<void> _say(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

void main() {
  late _RecordingPlanRepository plan;
  late _FakeOnboardingRepository onboarding;
  late _FakeNotificationService notifications;

  setUp(() {
    plan = _RecordingPlanRepository();
    onboarding = _FakeOnboardingRepository();
    notifications = _FakeNotificationService();
  });

  Future<void> pumpChat(WidgetTester tester, MealParserService parser) async {
    await tester.pumpWidget(
      _app(
        parser: parser,
        plan: plan,
        onboarding: onboarding,
        notifications: notifications,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens by asking about breakfast', (tester) async {
    await pumpChat(tester, _StubParser((_, __) => _ok()));

    expect(find.text('Tell me about your usual breakfast.'), findsWidgets);
    expect(find.text('Your usual breakfast'), findsOneWidget);
  });

  testWidgets('sends what was typed to the parser, tagged with the slot',
      (tester) async {
    final parser = _StubParser((_, __) => _ok());
    await pumpChat(tester, parser);

    await _say(tester, 'six eggs');

    expect(parser.calls.single.text, 'six eggs');
    expect(parser.calls.single.slot, MealSlot.breakfast);
  });

  testWidgets('shows parsed items for confirmation before saving anything',
      (tester) async {
    await pumpChat(tester, _StubParser((_, __) => _ok()));

    await _say(tester, 'six eggs');

    expect(find.text('6 large Egg'), findsOneWidget);
    expect(find.text('Looks right, save it'), findsOneWidget);
    // Nothing reaches the plan until the user confirms.
    expect(plan.saved, isEmpty);
  });

  testWidgets('confirming saves the meal and moves on to lunch',
      (tester) async {
    await pumpChat(tester, _StubParser((_, __) => _ok()));

    await _say(tester, 'six eggs');
    await tester.tap(find.text('Looks right, save it'));
    await tester.pumpAndSettle();

    expect(plan.saved.single.slot, MealSlot.breakfast);
    expect(plan.saved.single.items.single.name, 'Egg');
    expect(find.text('Your usual lunch'), findsOneWidget);
  });

  testWidgets('a clarifying question is shown with the items it did get',
      (tester) async {
    await pumpChat(
      tester,
      _StubParser(
        (_, __) => const ParseResult(
          items: [_eggs],
          needsClarification: true,
          question: 'How many slices of toast?',
        ),
      ),
    );

    await _say(tester, 'six eggs and some toast');

    expect(find.text('How many slices of toast?'), findsOneWidget);
    expect(find.text('6 large Egg'), findsOneWidget);
  });

  testWidgets('an unreadable answer asks again instead of dead-ending',
      (tester) async {
    await pumpChat(
      tester,
      _StubParser(
        (_, __) => const ParseResult(
          items: [],
          needsClarification: true,
          question: 'What do you usually have?',
        ),
      ),
    );

    await _say(tester, 'the usual');

    expect(find.text('What do you usually have?'), findsOneWidget);
    expect(find.text('Looks right, save it'), findsNothing);
    // Still on breakfast, so they can try again.
    expect(find.text('Your usual breakfast'), findsOneWidget);
  });

  testWidgets('a parser outage is reported without losing the chat',
      (tester) async {
    await pumpChat(tester, _ThrowingParser());

    await _say(tester, 'six eggs');

    expect(find.text('No connection.'), findsOneWidget);
    expect(find.text('Your usual breakfast'), findsOneWidget);
  });

  testWidgets('skip moves to the next meal without saving', (tester) async {
    await pumpChat(tester, _StubParser((_, __) => _ok()));

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(plan.saved, isEmpty);
    expect(find.text('Your usual lunch'), findsOneWidget);
  });

  testWidgets('finishing all four meals completes onboarding', (tester) async {
    await pumpChat(tester, _StubParser((_, __) => _ok()));

    for (var slot = 0; slot < 4; slot++) {
      await _say(tester, 'six eggs');
      await tester.tap(find.text('Looks right, save it'));
      await tester.pumpAndSettle();
    }

    expect(plan.saved.length, 4);
    expect(plan.saved.map((m) => m.slot), [
      MealSlot.breakfast,
      MealSlot.lunch,
      MealSlot.dinner,
      MealSlot.snack,
    ]);
    expect(onboarding.done, isTrue);
    expect(find.text('today screen'), findsOneWidget);
  });

  testWidgets('reminders are scheduled from the quiz answers', (tester) async {
    await pumpChat(tester, _StubParser((_, __) => _ok()));

    for (var slot = 0; slot < 4; slot++) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }

    // Profile says they train at 06:30, so the morning nudge lands an hour on.
    expect(notifications.morning?.formatted, '07:30');
    expect(notifications.evening?.formatted, '20:00');
  });

  testWidgets('onboarding still completes when notifications are refused',
      (tester) async {
    notifications.permissionsGranted = false;
    await pumpChat(tester, _StubParser((_, __) => _ok()));

    for (var slot = 0; slot < 4; slot++) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }

    expect(notifications.morning, isNull);
    expect(onboarding.done, isTrue);
    expect(find.text('today screen'), findsOneWidget);
  });
}
