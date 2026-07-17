import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/models/document.dart' show authStateChangesProvider;
import '../../features/shell/main_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/library_screen.dart';
import '../../features/home/study_hub_screen.dart';
import '../../features/upload/upload_screen.dart';
import '../../features/document/document_summary_screen.dart';
import '../../features/document/flashcards_screen.dart';
import '../../features/document/quiz_screen.dart';
import '../../features/document/resources_screen.dart';
import '../../features/tutor/ai_tutor_screen.dart';
import '../../features/planner/study_planner_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/account_screen.dart';
import '../../features/subscription/subscription_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Firebase's cached auth persistence means authStateChanges() can fire
// within a single frame on a warm start — without this, the splash screen
// would mount and unmount before its pulse animation is even visible. This
// is NOT autoDispose, so it only ever delays the very first app launch, not
// every later sign-in/out redirect.
final _splashMinDurationProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(milliseconds: 1200));
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // Watching this (rather than reading FirebaseAuth.instance.currentUser once)
  // means a sign-in or sign-out rebuilds this provider — and with it, the
  // GoRouter instance — so the redirect below always sees fresh auth state.
  final authState = ref.watch(authStateChangesProvider);
  final minSplashElapsed = ref.watch(_splashMinDurationProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/auth';
      final isOnboarding = loc == '/onboarding';

      // Still waiting on the first authStateChanges() event — park on the
      // splash screen rather than guessing signed-in/signed-out.
      final authResolved =
          (authState.hasValue || authState.hasError) && minSplashElapsed.hasValue;
      if (!authResolved) {
        return isSplash ? null : '/splash';
      }

      final loggedIn = authState.valueOrNull != null;

      if (!loggedIn) {
        // Public routes for a signed-out user. Everything else bounces to
        // onboarding, which itself links into /auth.
        return (isAuthRoute || isOnboarding) ? null : '/onboarding';
      }

      // Signed in — don't let them land back on splash/auth/onboarding.
      if (isSplash || isAuthRoute || isOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/subscription',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/upload',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/document/:id/summary',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => DocumentSummaryScreen(
          documentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/document/:id/flashcards',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => FlashcardsScreen(
          documentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/document/:id/quiz',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => QuizScreen(
          documentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/document/:id/resources',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ResourcesScreen(
          documentId: state.pathParameters['id']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/library', builder: (c, s) => const LibraryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/study', builder: (c, s) => const StudyHubScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/planner', builder: (c, s) => const StudyPlannerScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/tutor',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AiTutorScreen(
          documentId: state.uri.queryParameters['documentId'],
        ),
      ),
    ],
  );
});