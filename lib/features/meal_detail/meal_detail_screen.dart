import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/gemini_service.dart';
import '../../core/database/isar_service.dart';
import '../../core/models/meal.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/providers/dashboard_provider.dart';

class MealDetailScreen extends ConsumerStatefulWidget {
  const MealDetailScreen({super.key, required this.mealId});
  final int mealId;

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  Meal? _meal;
  bool _loading = true;
  bool _reAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meal = await isarService.getMeal(widget.mealId);
    setState(() {
      _meal = meal;
      _loading = false;
    });
  }

  Future<void> _editDateOnly() async {
    if (_meal == null) return;
    HapticFeedback.lightImpact();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _meal!.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Don't allow future dates
    );
    if (pickedDate == null || !mounted) return;

    final normalizedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);

    setState(() {
      _meal!.date = normalizedDate;
      _meal!.updatedAt = DateTime.now();
    });

    await isarService.saveMeal(_meal!);
    ref.invalidate(todaySnapshotProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal date updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editTimeOnly() async {
    if (_meal == null) return;
    HapticFeedback.lightImpact();

    final parts = _meal!.time.split(':');
    final initialHour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 12) : 12;
    final initialMin = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
    );
    if (pickedTime == null || !mounted) return;

    final formattedTime =
        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
    final inferredType = MealType.fromTime(DateTime(
      _meal!.date.year,
      _meal!.date.month,
      _meal!.date.day,
      pickedTime.hour,
      pickedTime.minute,
    ));

    setState(() {
      _meal!.time = formattedTime;
      _meal!.mealType = inferredType;
      _meal!.updatedAt = DateTime.now();
    });

    await isarService.saveMeal(_meal!);
    ref.invalidate(todaySnapshotProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal time updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editAndReAnalyze() async {
    if (_meal == null) return;
    HapticFeedback.lightImpact();

    final controller = TextEditingController(text: _meal!.originalUserInput);
    final resultText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit & Re-Analyse Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change your meal description below to re-analyse with AI:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. 2 eggs, 1 toast, 1 black coffee',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Re-Analyse'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (resultText == null || resultText.trim().isEmpty || !mounted) return;

    final hasKey = await GeminiService.instance.hasApiKey();
    if (!hasKey) {
      if (mounted) {
        await showApiKeyMissingDialog(context);
      }
      return;
    }

    setState(() => _reAnalyzing = true);

    try {
      final aiResult = await GeminiService.instance.analyzeMeal(text: resultText.trim());
      setState(() {
        _meal!.originalUserInput = resultText.trim();
        _meal!.aiInterpretation = aiResult.mealName;
        _meal!.aiConfidence = aiResult.confidence;
        _meal!.items = aiResult.items;
        _meal!.recalculateTotals();
        _meal!.updatedAt = DateTime.now();
        _reAnalyzing = false;
      });

      await isarService.saveMeal(_meal!);
      ref.invalidate(todaySnapshotProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal re-analysed and updated!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _reAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-analysis failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editNumber(String label, double currentValue, ValueChanged<double> onSave) async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController(text: currentValue.toStringAsFixed(0));
    final resultStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            suffixText: label.contains('Calories') ? 'kcal' : 'g',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    if (resultStr != null && resultStr.isNotEmpty) {
      final newVal = double.tryParse(resultStr);
      if (newVal != null && _meal != null) {
        onSave(newVal);
        _meal!.userEdited = true;
        _meal!.updatedAt = DateTime.now();
        await isarService.saveMeal(_meal!);
        ref.invalidate(todaySnapshotProvider);
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading || _reAnalyzing) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _reAnalyzing ? 'Re-analysing with Gemini AI...' : 'Loading meal...',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_meal == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('Meal not found')),
      );
    }

    final meal = _meal!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(meal.mealType.label),
        actions: [
          IconButton(
            icon: Icon(
              meal.isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
              color: meal.isFavorite ? Colors.red : null,
            ),
            tooltip: meal.isFavorite ? 'Remove from Saved Meals' : 'Save to Memory',
            onPressed: () async {
              meal.isFavorite = !meal.isFavorite;
              meal.updatedAt = DateTime.now();
              await isarService.saveMeal(meal);
              setState(() {});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(meal.isFavorite ? 'Saved to Memory ❤️' : 'Removed from Saved Meals'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Delete meal?'),
                  content: const Text('This action cannot be undone.'),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  actions: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ctx.pop(false),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => ctx.pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error,
                              foregroundColor: cs.onError,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await isarService.deleteMeal(meal.id);
                if (context.mounted) {
                  context.pop();
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal name header with edit/re-analyse icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    meal.aiInterpretation ?? meal.originalUserInput,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _editAndReAnalyze,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit text & re-analyse with AI',
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Separate Date and Time selection buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _editDateOnly,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '${meal.date.day}/${meal.date.month}/${meal.date.year}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                Text(
                  ' at ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                ),
                InkWell(
                  onTap: _editTimeOnly,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      meal.time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            ),

            if (meal.originalUserInput.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"${meal.originalUserInput}"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],

            // Image
            if (meal.imagePath != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.9),
                    builder: (ctx) => Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.file(
                              File(meal.imagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          left: 20,
                          child: Material(
                            color: Colors.black26,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(meal.imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Macro summary with tap-to-edit numbers (no pencil icons)
            _MacroGrid(
              meal: meal,
              onEditCalories: (v) => _editNumber('Total Calories', meal.totalCalories, (val) => meal.totalCalories = val),
              onEditProtein: (v) => _editNumber('Protein (g)', meal.totalProteinG, (val) => meal.totalProteinG = val),
              onEditCarbs: (v) => _editNumber('Carbs (g)', meal.totalCarbsG, (val) => meal.totalCarbsG = val),
              onEditFat: (v) => _editNumber('Fat (g)', meal.totalFatG, (val) => meal.totalFatG = val),
            ),

            const SizedBox(height: 24),

            // Items
            Text(
              'Food Items',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...meal.items.map((item) => _DetailItemRow(
                  item: item,
                  onEditItem: () => _editItemNumbers(item),
                )),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _editItemNumbers(MealItem item) async {
    HapticFeedback.lightImpact();
    final calCtrl = TextEditingController(text: item.calories.toStringAsFixed(0));
    final pCtrl = TextEditingController(text: item.proteinG.toStringAsFixed(0));
    final cCtrl = TextEditingController(text: item.carbsG.toStringAsFixed(0));
    final fCtrl = TextEditingController(text: item.fatG.toStringAsFixed(0));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    if (saved == true && _meal != null) {
      item.calories = double.tryParse(calCtrl.text) ?? item.calories;
      item.proteinG = double.tryParse(pCtrl.text) ?? item.proteinG;
      item.carbsG = double.tryParse(cCtrl.text) ?? item.carbsG;
      item.fatG = double.tryParse(fCtrl.text) ?? item.fatG;
      _meal!.recalculateTotals();
      _meal!.userEdited = true;
      _meal!.updatedAt = DateTime.now();
      await isarService.saveMeal(_meal!);
      ref.invalidate(todaySnapshotProvider);
      setState(() {});
    }
  }
}

class _MacroGrid extends StatelessWidget {
  const _MacroGrid({
    required this.meal,
    required this.onEditCalories,
    required this.onEditProtein,
    required this.onEditCarbs,
    required this.onEditFat,
  });

  final Meal meal;
  final ValueChanged<double> onEditCalories;
  final ValueChanged<double> onEditProtein;
  final ValueChanged<double> onEditCarbs;
  final ValueChanged<double> onEditFat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onEditCalories(meal.totalCalories),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    meal.totalCalories.toStringAsFixed(0),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: cs.primary),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('kcal',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                'Protein',
                '${meal.totalProteinG.toStringAsFixed(0)}g',
                AppTheme.proteinColor,
                onTap: () => onEditProtein(meal.totalProteinG),
              ),
              _Stat(
                'Carbs',
                '${meal.totalCarbsG.toStringAsFixed(0)}g',
                AppTheme.carbsColor,
                onTap: () => onEditCarbs(meal.totalCarbsG),
              ),
              _Stat(
                'Fat',
                '${meal.totalFatG.toStringAsFixed(0)}g',
                AppTheme.fatColor,
                onTap: () => onEditFat(meal.totalFatG),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color, {required this.onTap});
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItemRow extends StatelessWidget {
  const _DetailItemRow({required this.item, required this.onEditItem});
  final MealItem item;
  final VoidCallback onEditItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onEditItem,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      '${item.calories.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.servingDescription} · ${item.estimatedWeightG.toStringAsFixed(0)}g',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _Chip('P ${item.proteinG.toStringAsFixed(0)}g', AppTheme.proteinColor),
                    _Chip('C ${item.carbsG.toStringAsFixed(0)}g', AppTheme.carbsColor),
                    _Chip('F ${item.fatG.toStringAsFixed(0)}g', AppTheme.fatColor),
                  ],
                ),
              ],
            ),
          ),
        ),
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
