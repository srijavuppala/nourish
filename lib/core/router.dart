import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/checkin/screens/checkin_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/notifications/notification_service.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/screens/chat_screen.dart';
import '../features/onboarding/screens/quiz_screen.dart';
import '../features/plan/screens/plan_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/today/screens/today_screen.dart';
import '../shared/widgets/tab_shell.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const quiz = '/onboarding/quiz';
  static const chat = '/onboarding/chat';
  static const today = '/today';
  static const plan = '/plan';
  static const history = '/history';
  static const profile = '/profile';
  static const checkin = '/checkin';
}

/// Republishes a Listenable whenever the given providers change, so go_router
/// re-runs its redirect on sign-in and on onboarding completing.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    // A notification tap on a cold start lands directly on the check-in.
    initialLocation: NotificationService.launchPayload == checkinPayload
        ? Routes.checkin
        : Routes.today,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final onboarding = ref.read(onboardingDoneProvider);

      // Hold still until Firebase has answered; main.dart shows a splash.
      if (auth.isLoading) return null;

      final signedIn = auth.valueOrNull != null;
      final location = state.matchedLocation;

      if (!signedIn) {
        return location == Routes.signIn ? null : Routes.signIn;
      }

      if (onboarding.isLoading) return null;
      final onboardingDone = onboarding.valueOrNull ?? false;
      final inOnboarding = location.startsWith('/onboarding');

      if (!onboardingDone) return inOnboarding ? null : Routes.quiz;

      // Signed in and set up: keep them out of sign-in and onboarding.
      if (location == Routes.signIn || inOnboarding) return Routes.today;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.quiz,
        builder: (context, state) => const QuizScreen(),
      ),
      GoRoute(
        path: Routes.chat,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: Routes.checkin,
        builder: (context, state) => const CheckinScreen(),
      ),
      // The four tabs keep their own navigation state.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.today,
              builder: (context, state) => const TodayScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.plan,
              builder: (context, state) => const PlanScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.history,
              builder: (context, state) => const HistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
