// Declares every route and keeps navigation aligned with authentication state.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/application/auth_providers.dart';
import '../../features/authentication/domain/session_state.dart';
import '../../features/authentication/presentation/auth_screen.dart';
import '../../features/authentication/presentation/verify_email_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/habits/presentation/habits_wellness_screen.dart';
import '../../features/maps/presentation/study_locations_screen.dart';
import '../../features/ai_assistant/presentation/ai_assistant_screen.dart';
import '../../features/ai_planner/presentation/planner_entry_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/startup/presentation/startup_screen.dart';
import 'mento_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshListenable();
  ref.listen<SessionState>(sessionProvider, (_, __) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/startup',
    refreshListenable: refresh,
    redirect: (context, state) {
      // This is the single navigation guard for startup, sign-in, verification,
      // onboarding, and the authenticated application.
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final public =
          location == '/startup' ||
          location == '/auth' ||
          location == '/verify' ||
          location == '/onboarding';
      return switch (session.status) {
        SessionStatus.initializing =>
          location == '/startup' ? null : '/startup',
        SessionStatus.signedOut => location == '/auth' ? null : '/auth',
        SessionStatus.emailVerificationRequired =>
          location == '/verify' ? null : '/verify',
        SessionStatus.onboardingRequired =>
          location == '/onboarding' ? null : '/onboarding',
        SessionStatus.authenticated ||
        SessionStatus.demo => public ? '/today' : null,
      };
    },
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/wellbeing',
        builder: (context, state) => const HabitsWellnessScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const StudyLocationsScreen(),
      ),
      GoRoute(
        path: '/assistant',
        builder: (context, state) => const AiAssistantScreen(),
      ),
      GoRoute(
        path: '/planner',
        builder: (context, state) => const PlannerEntryScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                MentoShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/focus',
                builder: (context, state) => const FocusScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

final class _RouterRefreshListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}
