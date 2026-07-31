import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/isar_service.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Image.asset(
                    isDark
                        ? 'assets/images/splash_logo_dark.png'
                        : 'assets/images/splash_logo_light.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Bite',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Describe what you ate.\nLet AI do the rest.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 24),
              ...[
                (Icons.chat_bubble_outline_rounded, 'Natural language logging',
                    'Just type "one plate biryani" — no forms'),
                (Icons.camera_alt_outlined, 'Photo recognition',
                    'Snap a photo and AI identifies everything'),
                (Icons.bar_chart_rounded, 'Instant insights',
                    'See calories and macros in real time'),
              ].map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.$1,
                          color: cs.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                          Text(item.$3,
                              style: TextStyle(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.5),
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final settings =
                      await isarService.getOrCreateSettings();
                  settings.onboardingComplete = true;
                  await isarService.saveSettings(settings);
                  if (context.mounted) context.goNamed('dashboard');
                },
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
