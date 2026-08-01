import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/database/isar_service.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/meal.dart';
import '../../core/services/backup_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/expressive_slider.dart';
import '../dashboard/providers/dashboard_provider.dart';
import 'providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header with back arrow (slides back to caller) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.goNamed('dashboard');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Settings',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

            settingsAsync.when(
              data: (settings) {
                final heightStr = (settings.heightCm > 0 && !settings.heightCm.isNaN)
                    ? '${settings.heightCm.round()} cm'
                    : '170 cm';
                final weightStr = (settings.weightKg > 0 && !settings.weightKg.isNaN)
                    ? '${settings.weightKg.toStringAsFixed(1)} kg'
                    : '70.0 kg';
                final ageStr =
                    (settings.ageYears > 0) ? '${settings.ageYears} yrs' : '25 yrs';

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Goal Calculator & Personal Info ──
                    _SectionHeader('Goal Calculator & Personal Info'),
                    _BackupTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Info',
                      subtitle: 'Height ($heightStr), Weight ($weightStr), Age ($ageStr)',
                      color: cs.primary,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/settings/personal-info');
                      },
                    ),
                    _BackupTile(
                      icon: Icons.calculate_outlined,
                      title: 'Goal Calculator',
                      subtitle: 'Calculate target calories & macros from weight goal',
                      color: cs.tertiary,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/settings/goal-calculator');
                      },
                    ),
                    const SizedBox(height: 8),

                  // ── Nutrition Goals ──
                  _SectionHeader('Nutrition Goals'),
                  _GoalTile(
                    label: 'Daily Calories',
                    value: settings.goalCalories,
                    unit: 'kcal',
                    min: 1000,
                    max: 5000,
                    divisions: 40, // Increment in steps of 100
                    icon: Icons.local_fire_department_rounded,
                    onChanged: (v) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateGoals(calories: v),
                  ),
                  _GoalTile(
                    label: 'Daily Protein',
                    value: settings.goalProteinG,
                    unit: 'g',
                    min: 10,
                    max: 300,
                    divisions: 29, // Increment in steps of 10
                    icon: Icons.fitness_center_rounded,
                    onChanged: (v) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateGoals(protein: v),
                  ),
                  _GoalTile(
                    label: 'Daily Carbs',
                    value: settings.goalCarbsG,
                    unit: 'g',
                    min: 50,
                    max: 500,
                    divisions: 45, // Increment in steps of 10
                    icon: Icons.bakery_dining_rounded,
                    onChanged: (v) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateGoals(carbs: v),
                  ),
                  _GoalTile(
                    label: 'Daily Fat',
                    value: settings.goalFatG,
                    unit: 'g',
                    min: 20,
                    max: 200,
                    divisions: 36, // Increment in steps of 5
                    icon: Icons.cake_rounded,
                    onChanged: (v) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateGoals(fat: v),
                  ),

                  const SizedBox(height: 8),
                  // ── Appearance ──
                  _SectionHeader('Appearance'),
                  _ThemeTile(
                    current: settings.themeMode,
                    onChanged: (mode) => ref
                        .read(settingsNotifierProvider.notifier)
                        .setThemeMode(mode),
                  ),
                  const SizedBox(height: 4),
                  _ThemeStyleTile(
                    isExpressive: settings.isMaterial3Expressive,
                    onChanged: (isExpressive) => ref
                        .read(settingsNotifierProvider.notifier)
                        .setMaterial3Expressive(isExpressive),
                  ),
                  const SizedBox(height: 4),
                  _CustomColorSelectorTile(
                    selectedName: settings.customColorName,
                    enabled: !settings.isMaterial3Expressive,
                    onSelect: (opt) => ref
                        .read(settingsNotifierProvider.notifier)
                        .setCustomColor(opt.name, opt.colorValue),
                  ),
                  const SizedBox(height: 8),

                  // ── Data & Backup ──
                  _SectionHeader('Data & Backup'),
                  _BackupTile(
                    icon: Icons.bookmark_added_rounded,
                    title: 'Saved Meals',
                    subtitle: 'Manage and edit favorited meals in memory',
                    color: cs.secondary,
                    onTap: () => _showSavedMealsManagementDialog(context, ref),
                  ),
                  _BackupTile(
                    icon: Icons.upload_rounded,
                    title: 'Export Data',
                    subtitle: 'Save all meals & settings as a ZIP file',
                    color: cs.primary,
                    onTap: () => BackupService.instance.exportBackup(context),
                  ),
                  _BackupTile(
                    icon: Icons.download_rounded,
                    title: 'Import Data',
                    subtitle: 'Restore from a Bite backup ZIP',
                    color: cs.tertiary,
                    onTap: () => BackupService.instance.importBackup(context),
                  ),

                  const SizedBox(height: 8),

                  // ── Notifications ──
                  _SectionHeader('Notifications'),
                  _ReminderTile(
                    enabled: settings.mealRemindersEnabled,
                    onChanged: (v) => ref
                        .read(settingsNotifierProvider.notifier)
                        .setMealRemindersEnabled(v),
                  ),

                  const SizedBox(height: 8),

                  // ── AI Settings ──
                  _SectionHeader('AI Settings'),
                  _ApiKeyTile(
                    currentKey: settings.geminiApiKeyOverride,
                    onSave: (key) => ref
                        .read(settingsNotifierProvider.notifier)
                        .setGeminiApiKey(key),
                  ),

                  const SizedBox(height: 8),

                  // ── About ──
                  _SectionHeader('About'),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Bite'),
                    subtitle: const Text('v3.0.2 • AI-powered meal tracker'),
                  ),
                  const SizedBox(height: 40),
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavedMealsManagementDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedMealsManagementSheet(ref: ref),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Goal Tile — Expressive M3 Slider + Manual Number Input Dialog
// ─────────────────────────────────────────────────────────────────
class _GoalTile extends StatefulWidget {
  const _GoalTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.icon,
  });
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final IconData? icon;
  @override
  State<_GoalTile> createState() => _GoalTileState();
}

class _GoalTileState extends State<_GoalTile> {
  late double _current;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
  }

  @override
  void didUpdateWidget(covariant _GoalTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _current = widget.value;
    }
  }

  Future<void> _showManualInputDialog() async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController(text: _current.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set ${widget.label}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: widget.unit,
            hintText:
                'Enter value (${widget.min.toInt()} - ${widget.max.toInt()})',
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
      final clamped = result.clamp(widget.min, widget.max);
      setState(() => _current = clamped);
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Tooltip(
                message: 'Tap to enter manually',
                child: Material(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _showManualInputDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_current.toStringAsFixed(0)} ${widget.unit}',
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color:
                                  cs.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpressiveSlider(
            value: _current.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            icon: widget.icon,
            onChanged: (v) => setState(() => _current = v),
            onChangeEnd: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Theme Tile
// ─────────────────────────────────────────────────────────────────
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.current, required this.onChanged});
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          Text(
            'Theme',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.wb_auto_rounded),
                  tooltip: 'System'),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.wb_sunny_outlined),
                  tooltip: 'Light'),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  tooltip: 'Dark'),
            ],
            selected: {current},
            onSelectionChanged: (s) => onChanged(s.first),
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeStyleTile extends StatelessWidget {
  const _ThemeStyleTile({required this.isExpressive, required this.onChanged});
  final bool isExpressive;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          Text(
            'Theme Style',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Normal'),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Material U 3'),
              ),
            ],
            selected: {isExpressive},
            onSelectionChanged: (s) {
              HapticFeedback.lightImpact();
              onChanged(s.first);
            },
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeColorOption {
  final String name;
  final int colorValue;
  const ThemeColorOption(this.name, this.colorValue);
}

const List<ThemeColorOption> _themeColors = [
  ThemeColorOption('Default', 0xFF27272A),
  ThemeColorOption('Monotone', 0xFF000000),
  ThemeColorOption('Pink', 0xFFEC4899),
  ThemeColorOption('Blue', 0xFF3B82F6),
  ThemeColorOption('Green', 0xFF10B981),
  ThemeColorOption('Purple', 0xFF8B5CF6),
  ThemeColorOption('Orange', 0xFFF97316),
  ThemeColorOption('Teal', 0xFF14B8A6),
  ThemeColorOption('Red', 0xFFEF4444),
];

class _CustomColorSelectorTile extends StatelessWidget {
  const _CustomColorSelectorTile({
    required this.selectedName,
    required this.enabled,
    required this.onSelect,
  });
  final String selectedName;
  final bool enabled;
  final ValueChanged<ThemeColorOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Custom Theme Color',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _themeColors.map((opt) {
                    final isSelected = opt.name == selectedName;
                    final color = Color(opt.colorValue);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onSelect(opt);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: isSelected
                                ? Border.all(color: cs.primary, width: 2.5)
                                : Border.all(
                                    color: cs.onSurface.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: color.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Selected theme: $selectedName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(!enabled);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meal Reminders',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Remind me to log meals if I forget',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.55),
                                fontSize: 12.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      onChanged(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Backup Tile
// ─────────────────────────────────────────────────────────────────
class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// API Key Tile
// ─────────────────────────────────────────────────────────────────
class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({this.currentKey, required this.onSave});
  final String? currentKey;
  final ValueChanged<String> onSave;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: const Icon(Icons.key_rounded),
      title: const Text('Gemini API Key'),
      subtitle: Text(
        widget.currentKey != null && widget.currentKey!.trim().isNotEmpty
            ? '••••••••••${widget.currentKey!.length > 8 ? widget.currentKey!.substring(widget.currentKey!.length - 4) : ''}'
            : 'Not configured (Tap to set)',
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () async {
        HapticFeedback.lightImpact();
        final controller = TextEditingController(text: widget.currentKey);
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Gemini API Key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'AIzaSy...',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mini Setup Guide:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text('1. Tap below to open Google AI Studio in browser.', style: TextStyle(fontSize: 11)),
                      const Text('2. Sign in & tap "Create API Key".', style: TextStyle(fontSize: 11)),
                      const Text('3. Copy your key & paste it above.', style: TextStyle(fontSize: 11)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('https://aistudio.google.com/app/apikey');
                            try {
                              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (launched) return;
                            } catch (_) {}
                            await Clipboard.setData(ClipboardData(text: uri.toString()));
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('URL copied to clipboard! Paste in browser to open AI Studio. 📋'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text(
                            'Open Google AI Studio ↗',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      onPressed: () => Navigator.of(ctx).pop(controller.text),
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
          widget.onSave(result.trim());
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Saved Meals Management Sheet
// ─────────────────────────────────────────────────────────────────
class _SavedMealsManagementSheet extends StatefulWidget {
  const _SavedMealsManagementSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_SavedMealsManagementSheet> createState() =>
      _SavedMealsManagementSheetState();
}

class _SavedMealsManagementSheetState
    extends State<_SavedMealsManagementSheet> {
  List<Meal> _savedMeals = [];
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await isarService.getFavoriteMeals();
    if (mounted) {
      setState(() {
        _savedMeals = favs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    final filtered = _savedMeals.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (m.aiInterpretation ?? m.originalUserInput).toLowerCase();
      return name.contains(q);
    }).toList();

    return Container(
      height: mq.size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Saved Meals (Memory)',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search saved meals...',
                prefixIcon: const Icon(Icons.search_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No saved meals found.'
                              : 'No matching meals.',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final meal = filtered[i];
                          return _SavedMealCard(
                            meal: meal,
                            onToggleFavorite: () async {
                              meal.isFavorite = !meal.isFavorite;
                              meal.updatedAt = DateTime.now();
                              await isarService.saveMeal(meal);
                              widget.ref.invalidate(todaySnapshotProvider);
                              _load();
                            },
                            onEdit: () async {
                              await _editMealDialog(context, meal);
                              widget.ref.invalidate(todaySnapshotProvider);
                              _load();
                            },
                            onDelete: () async {
                              await isarService.deleteMeal(meal.id);
                              widget.ref.invalidate(todaySnapshotProvider);
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMealDialog(BuildContext context, Meal meal) async {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(
        text: meal.aiInterpretation ?? meal.originalUserInput);
    final calCtrl =
        TextEditingController(text: meal.totalCalories.toStringAsFixed(0));
    final pCtrl =
        TextEditingController(text: meal.totalProteinG.toStringAsFixed(0));
    final cCtrl =
        TextEditingController(text: meal.totalCarbsG.toStringAsFixed(0));
    final fCtrl =
        TextEditingController(text: meal.totalFatG.toStringAsFixed(0));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Saved Meal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Meal Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: calCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Calories',
                        suffixText: 'kcal',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: pCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Protein',
                        suffixText: 'g',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Carbs',
                        suffixText: 'g',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: fCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Fat',
                        suffixText: 'g',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

    if (saved == true) {
      meal.originalUserInput = nameCtrl.text.trim();
      meal.aiInterpretation = nameCtrl.text.trim();
      meal.totalCalories = double.tryParse(calCtrl.text) ?? meal.totalCalories;
      meal.totalProteinG = double.tryParse(pCtrl.text) ?? meal.totalProteinG;
      meal.totalCarbsG = double.tryParse(cCtrl.text) ?? meal.totalCarbsG;
      meal.totalFatG = double.tryParse(fCtrl.text) ?? meal.totalFatG;
      meal.userEdited = true;
      meal.updatedAt = DateTime.now();

      if (meal.items.isNotEmpty) {
        meal.items.first
          ..name = meal.aiInterpretation!
          ..calories = meal.totalCalories
          ..proteinG = meal.totalProteinG
          ..carbsG = meal.totalCarbsG
          ..fatG = meal.totalFatG;
      }

      await isarService.saveMeal(meal);
    }
  }
}

class _SavedMealCard extends StatelessWidget {
  const _SavedMealCard({
    required this.meal,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  final Meal meal;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  meal.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border,
                  color: meal.isFavorite ? Colors.red : null,
                ),
                onPressed: onToggleFavorite,
                tooltip: 'Toggle Favorite',
              ),
              Expanded(
                child: Text(
                  meal.aiInterpretation ?? meal.originalUserInput,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit saved meal',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _Chip(
                  '${meal.totalCalories.toStringAsFixed(0)} kcal', cs.primary),
              _Chip('P ${meal.totalProteinG.toStringAsFixed(0)}g',
                  AppTheme.proteinColor),
              _Chip('C ${meal.totalCarbsG.toStringAsFixed(0)}g',
                  AppTheme.carbsColor),
              _Chip(
                  'F ${meal.totalFatG.toStringAsFixed(0)}g', AppTheme.fatColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
