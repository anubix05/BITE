import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/nutrition_calculator.dart';
import '../../core/widgets/expressive_slider.dart';
import 'providers/settings_provider.dart';

class GoalCalculatorScreen extends ConsumerWidget {
  const GoalCalculatorScreen({super.key});

  Future<void> _showManualTargetWeightDialog(
      BuildContext context, WidgetRef ref, double currentTarget) async {
    HapticFeedback.lightImpact();
    final controller =
        TextEditingController(text: currentTarget.toStringAsFixed(1));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Target Weight Goal'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: 'kg',
            hintText: 'Enter target weight (30 - 200 kg)',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: Theme.of(ctx)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text.trim());
                    Navigator.of(ctx).pop(parsed);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary,
                    foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (result != null) {
      final clamped = result.clamp(30.0, 200.0);
      ref.read(settingsNotifierProvider.notifier).updateGoalCalculator(
            targetWeightKg: (clamped * 2).round() / 2,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) =>
              Center(child: Text('Error loading settings: $err')),
          data: (settings) {
            final currentWeight = settings.weightKg;
            final targetWeight = settings.targetWeightKg;
            final selectedRate = settings.weeklyRateKg;

            final result = NutritionCalculator.calculateTargets(
              heightCm: settings.heightCm,
              weightKg: currentWeight,
              ageYears: settings.ageYears,
              gender: settings.gender,
              activityLevelIndex: settings.activityLevelIndex,
              targetWeightKg: targetWeight,
              weeklyRateKg: selectedRate,
            );

            final isLoss = result.goalType == 'loss';
            final isGain = result.goalType == 'gain';
            final isMaintain = result.goalType == 'maintain';

            return CustomScrollView(
              slivers: [
                // Header with back arrow
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/settings');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Back to Settings',
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Goal Calculator',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Personal Metrics Summary Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Profile',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${currentWeight.toStringAsFixed(1)} kg  •  ${settings.heightCm.round()} cm  •  ${settings.ageYears} yrs',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                context.push('/settings/personal-info');
                              },
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Edit Profile'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Target Weight Selector Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.flag_rounded,
                                    color: cs.primary, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Target Weight Goal',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const Spacer(),
                                Tooltip(
                                  message: 'Tap to enter manually',
                                  child: Material(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () =>
                                          _showManualTargetWeightDialog(
                                              context, ref, targetWeight),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${targetWeight.toStringAsFixed(1)} kg',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color:
                                                        cs.onPrimaryContainer,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit_rounded,
                                              size: 14,
                                              color: cs.onPrimaryContainer
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ExpressiveSlider(
                              value: targetWeight.clamp(30.0, 200.0),
                              min: 30.0,
                              max: 200.0,
                              divisions: 340, // 0.5 kg steps
                              onChanged: (v) {
                                ref
                                    .read(settingsNotifierProvider.notifier)
                                    .updateGoalCalculator(
                                      targetWeightKg: (v * 2).round() /
                                          2, // Round to nearest 0.5kg
                                    );
                              },
                            ),
                            const SizedBox(height: 8),
                            // Goal Badge / Subtitle
                            Row(
                              children: [
                                Icon(
                                  isLoss
                                      ? Icons.trending_down_rounded
                                      : isGain
                                          ? Icons.trending_up_rounded
                                          : Icons.trending_flat_rounded,
                                  color: isLoss
                                      ? Colors.orange.shade700
                                      : isGain
                                          ? Colors.blue.shade700
                                          : Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isLoss
                                      ? 'Weight Loss Goal (${(currentWeight - targetWeight).toStringAsFixed(1)} kg reduction)'
                                      : isGain
                                          ? 'Weight Gain Goal (${(targetWeight - currentWeight).toStringAsFixed(1)} kg increase)'
                                          : 'Maintenance Goal (Maintain current weight)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isLoss
                                            ? Colors.orange.shade700
                                            : isGain
                                                ? Colors.blue.shade700
                                                : Colors.green.shade700,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Weekly Rate Selection (Only shown if Loss or Gain)
                      if (!isMaintain) ...[
                        Text(
                          isLoss
                              ? 'Rate of Weight Loss per Week'
                              : 'Rate of Weight Gain per Week',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoss
                              ? 'Select how aggressively you want to reduce your calories.'
                              : 'Select your target weekly weight gain pace.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [0.25, 0.5, 1.0].map((rate) {
                            final isSelected = selectedRate == rate;
                            final dailyDiff = (rate * 7700 / 7).round();
                            final sign = isLoss ? '-' : '+';

                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Material(
                                  color: isSelected
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      ref
                                          .read(
                                              settingsNotifierProvider.notifier)
                                          .updateGoalCalculator(
                                              weeklyRateKg: rate);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? cs.primary
                                              : cs.outlineVariant
                                                  .withValues(alpha: 0.3),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${rate.toStringAsFixed(2)} kg',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? cs.onPrimaryContainer
                                                      : cs.onSurface,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'per week',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: isSelected
                                                      ? cs.onPrimaryContainer
                                                          .withValues(
                                                              alpha: 0.8)
                                                      : cs.onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? cs.primary
                                                      .withValues(alpha: 0.15)
                                                  : cs.surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$sign$dailyDiff kcal',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected
                                                        ? cs.primary
                                                        : cs.onSurface,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Calculated Daily Recommendations Section
                      Text(
                        'Calculated Daily Targets',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Primary Calories Summary Card
                      Card(
                        elevation: 0,
                        color: cs.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.onPrimaryContainer
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.local_fire_department_rounded,
                                    color: cs.onPrimaryContainer, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Target Daily Calories',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: cs.onPrimaryContainer
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      '${result.targetCalories.round()} kcal',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: cs.onPrimaryContainer,
                                          ),
                                    ),
                                    Text(
                                      'TDEE Maintenance: ${result.tdee.round()} kcal/day',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: cs.onPrimaryContainer
                                                .withValues(alpha: 0.8),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Macro Distribution Row Cards
                      Row(
                        children: [
                          Expanded(
                            child: _MacroCard(
                              label: 'Protein (30%)',
                              grams: result.targetProteinG,
                              icon: Icons.fitness_center_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MacroCard(
                              label: 'Carbs (45%)',
                              grams: result.targetCarbsG,
                              icon: Icons.bakery_dining_rounded,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MacroCard(
                              label: 'Fat (25%)',
                              grams: result.targetFatG,
                              icon: Icons.cake_rounded,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            await ref
                                .read(settingsNotifierProvider.notifier)
                                .updateGoals(
                                  calories: result.targetCalories,
                                  protein: result.targetProteinG,
                                  carbs: result.targetCarbsG,
                                  fat: result.targetFatG,
                                );
                            if (context.mounted) {
                              final cs = Theme.of(context).colorScheme;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          color: cs.onInverseSurface),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Daily nutrition goals updated!',
                                        style: TextStyle(
                                            color: cs.onInverseSurface),
                                      ),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.only(
                                    bottom: 100,
                                    left: 16,
                                    right: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text(
                            'Apply to Daily Nutrition Goals',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double grams;
  final IconData icon;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.grams,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '${grams.round()} g',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
