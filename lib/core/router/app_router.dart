import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/log_meal/log_meal_screen.dart';
import '../../features/meal_detail/meal_detail_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/personal_info_screen.dart';
import '../../features/settings/goal_calculator_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../widgets/shell_scaffold.dart';

part 'app_router.g.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(settingsNotifierProvider, (_, __) => notifyListeners());
  }
}

@riverpod
GoRouter appRouter(Ref ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final settings = ref.read(settingsNotifierProvider).valueOrNull;
      if (settings != null && !settings.onboardingComplete) {
        if (state.matchedLocation != '/onboarding') {
          return '/onboarding';
        }
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            name: 'history',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CalendarScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'personal-info',
            name: 'personal_info',
            builder: (context, state) => const PersonalInfoScreen(),
          ),
          GoRoute(
            path: 'goal-calculator',
            name: 'goal_calculator',
            builder: (context, state) => const GoalCalculatorScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/log',
        name: 'log_meal',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const LogMealScreen(),
          transitionsBuilder: (context, animation, secondary, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/meal/:id',
        name: 'meal_detail',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CustomTransitionPage(
            child: MealDetailScreen(mealId: id),
            transitionsBuilder: (context, animation, secondary, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
}
