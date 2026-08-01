import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/nutrition_calculator.dart';
import '../../core/widgets/expressive_slider.dart';
import 'providers/settings_provider.dart';

class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error loading settings: $err')),
          data: (settings) {
            final height = settings.heightCm;
            final weight = settings.weightKg;
            final age = settings.ageYears;
            final gender = settings.gender;
            final activityIndex = settings.activityLevelIndex;

            final bmr = NutritionCalculator.calculateBmr(
              heightCm: height,
              weightKg: weight,
              ageYears: age,
              gender: gender,
            ).round();

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
                          'Personal Info',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // BMR Summary Card
                      Card(
                        elevation: 0,
                        color: cs.primaryContainer.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.bolt_rounded, color: cs.primary, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estimated BMR',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      '$bmr kcal / day',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: cs.primary,
                                          ),
                                    ),
                                    Text(
                                      'Basal Metabolic Rate at rest',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Gender Selection
                      Text(
                        'Biological Sex',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'male',
                            label: Text('Male'),
                            icon: Icon(Icons.male_rounded),
                          ),
                          ButtonSegment<String>(
                            value: 'female',
                            label: Text('Female'),
                            icon: Icon(Icons.female_rounded),
                          ),
                        ],
                        selected: {gender},
                        onSelectionChanged: (Set<String> newSelection) {
                          HapticFeedback.selectionClick();
                          ref.read(settingsNotifierProvider.notifier).updatePersonalInfo(
                                gender: newSelection.first,
                              );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Height Slider / Input
                      _MetricTile(
                        label: 'Height',
                        value: height,
                        unit: 'cm',
                        min: 120,
                        max: 220,
                        divisions: 100,
                        icon: Icons.height_rounded,
                        onChanged: (v) => ref
                            .read(settingsNotifierProvider.notifier)
                            .updatePersonalInfo(heightCm: v),
                      ),
                      const SizedBox(height: 16),

                      // Weight Slider / Input
                      _MetricTile(
                        label: 'Current Weight',
                        value: weight,
                        unit: 'kg',
                        min: 30,
                        max: 200,
                        divisions: 170,
                        icon: Icons.monitor_weight_rounded,
                        onChanged: (v) => ref
                            .read(settingsNotifierProvider.notifier)
                            .updatePersonalInfo(weightKg: v),
                      ),
                      const SizedBox(height: 16),

                      // Age Slider / Input
                      _MetricTile(
                        label: 'Age',
                        value: age.toDouble(),
                        unit: 'years',
                        min: 15,
                        max: 95,
                        divisions: 80,
                        icon: Icons.cake_rounded,
                        onChanged: (v) => ref
                            .read(settingsNotifierProvider.notifier)
                            .updatePersonalInfo(ageYears: v.round()),
                      ),
                      const SizedBox(height: 24),

                      // Activity Level Selector
                      Text(
                        'Daily Activity Level',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        NutritionCalculator.activityLabels.length,
                        (index) {
                          final isSelected = activityIndex == index;
                          final label = NutritionCalculator.activityLabels[index];
                          final parts = label.split(' (');
                          final title = parts[0];
                          final subtitle = parts.length > 1 ? parts[1].replaceAll(')', '') : '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Material(
                              color: isSelected
                                  ? cs.primaryContainer.withValues(alpha: 0.6)
                                  : cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(settingsNotifierProvider.notifier)
                                      .updatePersonalInfo(activityLevelIndex: index);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    children: [
                                      Radio<int>(
                                        value: index,
                                        // ignore: deprecated_member_use
                                        groupValue: activityIndex,
                                        // ignore: deprecated_member_use
                                        onChanged: (val) {
                                          if (val != null) {
                                            HapticFeedback.selectionClick();
                                            ref
                                                .read(settingsNotifierProvider.notifier)
                                                .updatePersonalInfo(activityLevelIndex: val);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                  ),
                                            ),
                                            if (subtitle.isNotEmpty)
                                              Text(
                                                subtitle,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: cs.onSurfaceVariant,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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

class _MetricTile extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final IconData icon;
  final ValueChanged<double> onChanged;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.icon,
    required this.onChanged,
  });

  Future<void> _showManualInputDialog(BuildContext context, String formattedVal) async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController(text: formattedVal);
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set $label'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: unit,
            hintText: 'Enter value (${min.toInt()} - ${max.toInt()})',
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
                      color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.3),
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
      final clamped = result.clamp(min, max);
      onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final formattedVal = unit == 'years' ? value.round().toString() : value.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Tap to enter manually',
                child: Material(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _showManualInputDialog(context, formattedVal),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$formattedVal $unit',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.7),
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
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
