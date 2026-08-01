import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/app_settings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart';

class BiteApp extends ConsumerWidget {
  const BiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    final themeMode = settingsAsync.when(
      data: (s) => s.themeMode,
      loading: () => ThemeMode.system,
      error: (_, __) => ThemeMode.system,
    );

    final settings = settingsAsync.valueOrNull;
    final isM3Expressive = settings?.isMaterial3Expressive ?? false;
    final seedColor = settings != null ? Color(settings.customColorValue) : null;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Bite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(
            dynamic: isM3Expressive ? lightDynamic : null,
            seedColor: seedColor,
          ),
          darkTheme: AppTheme.dark(
            dynamic: isM3Expressive ? darkDynamic : null,
            seedColor: seedColor,
          ),
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 250),
          themeAnimationCurve: Curves.easeInOutCubic,
          routerConfig: router,
          builder: (context, child) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
              },
              child: child ?? const SizedBox(),
            );
          },
        );
      },
    );

  }
}
