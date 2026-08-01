import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bite/core/models/app_settings.dart';
import 'package:bite/features/settings/providers/settings_provider.dart';
import 'package:bite/features/settings/settings_screen.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return AppSettings();
  }
}

void main() {
  testWidgets('SettingsScreen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsNotifierProvider.overrideWith(() => FakeSettingsNotifier()),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    // Initial pump (loading state)
    await tester.pump();
    // Finish async loading
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Personal Info'), findsOneWidget);
    expect(find.text('Goal Calculator'), findsOneWidget);
  });
}
