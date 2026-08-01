import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bite/core/models/app_settings.dart';
import 'package:bite/core/router/app_router.dart';
import 'package:bite/features/settings/providers/settings_provider.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return AppSettings()..onboardingComplete = true;
  }
}

class IncompleteOnboardingNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return AppSettings()..onboardingComplete = false;
  }
}

void main() {
  testWidgets('Redirects to /onboarding when onboardingComplete is false', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(() => IncompleteOnboardingNotifier()),
      ],
    );

    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    router.go('/onboarding');
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Bite'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Navigating to settings via appRouter works', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(() => FakeSettingsNotifier()),
      ],
    );

    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to settings
    router.push('/settings');
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Personal Info'), findsOneWidget);
    expect(find.text('Goal Calculator'), findsOneWidget);
  });
}
