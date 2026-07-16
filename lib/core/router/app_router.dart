import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/sign_up_screen.dart';
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
import '../../features/subscription/subscription_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/onboarding',
    routes: [
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