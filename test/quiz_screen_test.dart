import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nourish/core/app_user.dart';
import 'package:nourish/core/constants.dart';
import 'package:nourish/features/auth/data/auth_repository.dart';
import 'package:nourish/features/onboarding/data/onboarding_repository.dart';
import 'package:nourish/features/onboarding/models/profile.dart';
import 'package:nourish/features/onboarding/models/targets.dart';
import 'package:nourish/features/onboarding/screens/quiz_screen.dart';

class _RecordingOnboardingRepository implements OnboardingRepository {
  Profile? savedProfile;
  Targets? savedTargets;
  bool failSave = false;

  @override
  Future<void> saveProfile(Profile profile) async {
    if (failSave) throw Exception('offline');
    savedProfile = profile;
  }

  @override
  Future<void> saveTargets(Targets targets) async => savedTargets = targets;

  @override
  Future<void> ensureUserDocument(AppUser user) async {}
  @override
  Stream<bool> onboardingDone() => Stream.value(false);
  @override
  Future<void> markOnboardingDone() async {}
  @override
  Future<Profile?> loadProfile() async => savedProfile;
  @override
  Stream<Targets?> watchTargets() => Stream.value(savedTargets);
  @override
  Future<void> appendChatMessage({
    required String role,
    required String text,
    List<Map<String, dynamic>>? parsedItems,
  }) async {}
}

Widget _app(_RecordingOnboardingRepository repository) {
  final router = GoRouter(
    initialLocation: '/onboarding/quiz',
    routes: [
      GoRoute(path: '/onboarding/quiz', builder: (_, __) => const QuizScreen()),
      GoRoute(
        path: '/onboarding/chat',
        builder: (_, __) => const Scaffold(body: Text('chat screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(uid: 'u1')),
      ),
      onboardingRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Walks forward through the remaining steps, accepting whatever is on screen.
/// Taps whichever button is showing, so it works from any starting step.
Future<void> _finishQuiz(WidgetTester tester, {int steps = 6}) async {
  for (var step = 0; step < steps; step++) {
    final finish = find.text('Build my plan');
    final button = finish.evaluate().isNotEmpty ? finish : find.text('Continue');
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

void main() {
  late _RecordingOnboardingRepository repository;

  setUp(() => repository = _RecordingOnboardingRepository());

  Future<void> pumpQuiz(WidgetTester tester) async {
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the goal question', (tester) async {
    await pumpQuiz(tester);

    expect(find.text('What are you here for?'), findsOneWidget);
    expect(find.text('Lose weight'), findsOneWidget);
    expect(find.text('Build muscle'), findsOneWidget);
  });

  testWidgets('shows one question at a time', (tester) async {
    await pumpQuiz(tester);

    // The activity question exists later in the PageView but is not on screen.
    expect(find.text('What are you here for?'), findsOneWidget);
    expect(find.text('How active are you?'), findsNothing);
  });

  testWidgets('advances through all six steps to the chat', (tester) async {
    await pumpQuiz(tester);
    await _finishQuiz(tester);

    expect(find.text('chat screen'), findsOneWidget);
  });

  testWidgets('records the goal the user picked', (tester) async {
    await pumpQuiz(tester);

    await tester.tap(find.text('Lose weight'));
    await tester.pumpAndSettle();
    await _finishQuiz(tester);

    expect(repository.savedProfile?.goal, Goal.lose);
  });

  testWidgets('records the activity level the user picked', (tester) async {
    await pumpQuiz(tester);

    await tester.tap(find.text('Continue')); // goal
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // body basics
    await tester.pumpAndSettle();

    await tester.tap(find.text('Athlete or physical job'));
    await tester.pumpAndSettle();
    await _finishQuiz(tester, steps: 4);

    expect(repository.savedProfile?.activityLevel, ActivityLevel.veryActive);
  });

  testWidgets('the steppers change the recorded body numbers', (tester) async {
    await pumpQuiz(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Default weight is 70kg; three taps of plus makes it 73.
    final plusButtons = find.byIcon(Icons.add);
    for (var tap = 0; tap < 3; tap++) {
      await tester.tap(plusButtons.last);
      await tester.pumpAndSettle();
    }
    await _finishQuiz(tester, steps: 5);

    expect(repository.savedProfile?.weightKg, 73);
  });

  testWidgets('foods to avoid are split on commas and trimmed', (tester) async {
    await pumpQuiz(tester);

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(TextField), ' peanuts , dairy ,, ');
    await tester.pumpAndSettle();
    await _finishQuiz(tester, steps: 3);

    expect(repository.savedProfile?.avoids, ['peanuts', 'dairy']);
  });

  testWidgets('calculates targets from the answers, not from nothing',
      (tester) async {
    await pumpQuiz(tester);
    await _finishQuiz(tester);

    final targets = repository.savedTargets;
    expect(targets, isNotNull);
    expect(targets!.calories, greaterThan(1200));
    expect(targets.proteinG, greaterThan(0));
    // The reasoning is stored so Profile can explain the numbers later.
    expect(targets.explanation, contains('burn'));
  });

  testWidgets('a cut produces fewer calories than maintaining', (tester) async {
    await pumpQuiz(tester);
    await tester.tap(find.text('Lose weight'));
    await tester.pumpAndSettle();
    await _finishQuiz(tester);
    final cutting = repository.savedTargets!.calories;

    repository = _RecordingOnboardingRepository();
    await pumpQuiz(tester);
    await tester.tap(find.text('Maintain'));
    await tester.pumpAndSettle();
    await _finishQuiz(tester);

    expect(cutting, lessThan(repository.savedTargets!.calories));
  });

  testWidgets('going back keeps the earlier answer selected', (tester) async {
    await pumpQuiz(tester);

    await tester.tap(find.text('Build muscle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await _finishQuiz(tester);
    expect(repository.savedProfile?.goal, Goal.buildMuscle);
  });

  testWidgets('a failed save keeps the user on the quiz with a message',
      (tester) async {
    repository.failSave = true;
    await pumpQuiz(tester);
    await _finishQuiz(tester);

    expect(find.text("Couldn't save that. Try again."), findsOneWidget);
    expect(find.text('chat screen'), findsNothing);
  });
}
