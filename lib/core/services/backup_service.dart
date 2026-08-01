import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/isar_service.dart';
import '../models/meal.dart';
import '../models/app_settings.dart';

enum ExportScope { all, dateRange }

class ImportOptions {
  final bool importMeals;
  final bool importSettings;
  const ImportOptions({required this.importMeals, required this.importSettings});
}

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  // ─────────────── EXPORT ───────────────

  Future<void> exportBackup(BuildContext context) async {
    final scope = await showModalBottomSheet<ExportScope>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ExportScopeSheet(),
    );

    if (scope == null) return;

    DateTimeRange? dateRange;
    if (scope == ExportScope.dateRange) {
      if (!context.mounted) return;
      dateRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        ),
        helpText: 'Select Export Date Range',
      );
      if (dateRange == null) return;
    }

    try {
      final List<Meal> meals;
      final String stamp;
      if (dateRange != null) {
        meals = await isarService.getMealsInDateRange(dateRange.start, dateRange.end);
        final startStr = DateFormat('yyyy-MM-dd').format(dateRange.start);
        final endStr = DateFormat('yyyy-MM-dd').format(dateRange.end);
        stamp = '${startStr}_to_$endStr';
      } else {
        meals = await isarService.getAllMeals(limit: 999999);
        stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      }

      final settings = await isarService.getOrCreateSettings();

      final mealsJson = jsonEncode(meals.map(_mealToMap).toList());
      final settingsJson = jsonEncode(_settingsToMap(settings));
      final versionJson = jsonEncode({
        'version': '2.0.2',
        'exportedAt': DateTime.now().toIso8601String(),
        'exportScope': dateRange != null ? 'dateRange' : 'all',
        if (dateRange != null) 'startDate': dateRange.start.toIso8601String(),
        if (dateRange != null) 'endDate': dateRange.end.toIso8601String(),
      });

      final archive = Archive();
      archive.addFile(
          ArchiveFile('meals.json', mealsJson.length, utf8.encode(mealsJson)));
      archive.addFile(ArchiveFile(
          'settings.json', settingsJson.length, utf8.encode(settingsJson)));
      archive.addFile(ArchiveFile(
          'version.json', versionJson.length, utf8.encode(versionJson)));

      for (final meal in meals) {
        if (meal.imagePath != null) {
          final file = File(meal.imagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final name = 'images/${meal.id}_${file.uri.pathSegments.last}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final fileName = 'bite_backup_$stamp.zip';

      final String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Bite Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: zipBytes,
      );

      if (selectedPath != null) {
        final saveFile = File(selectedPath);
        if (!await saveFile.exists() || (await saveFile.length()) == 0) {
          await saveFile.writeAsBytes(zipBytes);
        }
        if (context.mounted) {
          final msg = dateRange != null
              ? 'Exported ${meals.length} meals for selected date range! 🎉'
              : 'All backup data saved successfully! 🎉';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─────────────── IMPORT ───────────────

  Future<void> importBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final zipPath = result.files.first.path!;

    if (!context.mounted) return;
    final options = await showDialog<ImportOptions>(
      context: context,
      builder: (ctx) => const _ImportOptionsDialog(),
    );
    if (options == null || (!options.importMeals && !options.importSettings)) return;

    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      if (options.importMeals) {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/meal_images');
        if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

        for (final file in archive) {
          if (file.name.startsWith('images/') && file.isFile) {
            final outPath = '${imagesDir.path}/${file.name.split('/').last}';
            await File(outPath).writeAsBytes(file.content as List<int>);
          }
        }

        final mealsFile = archive.findFile('meals.json');
        if (mealsFile != null) {
          final existingMeals = await isarService.getAllMeals(limit: 999999);

          final existingByCreatedAt = <String, Meal>{};
          final existingByCompositeKey = <String, Meal>{};

          for (final ex in existingMeals) {
            existingByCreatedAt[ex.createdAt.toIso8601String()] = ex;
            final key =
                '${ex.date.toIso8601String()}_${ex.time}_${ex.originalUserInput.trim().toLowerCase()}';
            existingByCompositeKey[key] = ex;
          }

          final mealsData =
              jsonDecode(utf8.decode(mealsFile.content as List<int>)) as List;

          for (final m in mealsData) {
            final mMap = m as Map<String, dynamic>;
            final importedMeal = _mealFromMap(mMap, imagesDir.path);

            final createdAtKey = importedMeal.createdAt.toIso8601String();
            final compositeKey =
                '${importedMeal.date.toIso8601String()}_${importedMeal.time}_${importedMeal.originalUserInput.trim().toLowerCase()}';

            final existing = existingByCreatedAt[createdAtKey] ??
                existingByCompositeKey[compositeKey];

            if (existing != null) {
              importedMeal.id = existing.id;
            } else {
              importedMeal.id = Isar.autoIncrement;
            }

            await isarService.saveMeal(importedMeal);
          }
        }
      }

      if (options.importSettings) {
        final settingsFile = archive.findFile('settings.json');
        if (settingsFile != null) {
          final settingsData =
              jsonDecode(utf8.decode(settingsFile.content as List<int>))
                  as Map<String, dynamic>;
          final current = await isarService.getOrCreateSettings();
          _applySettingsMap(current, settingsData);
          await isarService.saveSettings(current);
        }
      }

      if (context.mounted) {
        final String successMsg;
        if (options.importMeals && options.importSettings) {
          successMsg = 'Meals & Settings imported successfully! ✅';
        } else if (options.importMeals) {
          successMsg = 'Meal history imported successfully! ✅';
        } else {
          successMsg = 'Settings & daily goals imported successfully! ✅';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─────────────── Serialisation helpers ───────────────

  Map<String, dynamic> _mealToMap(Meal m) => {
        'id': m.id,
        'createdAt': m.createdAt.toIso8601String(),
        'updatedAt': m.updatedAt.toIso8601String(),
        'date': m.date.toIso8601String(),
        'time': m.time,
        'mealType': m.mealType.index,
        'originalUserInput': m.originalUserInput,
        'aiInterpretation': m.aiInterpretation,
        'imagePath': m.imagePath,
        'notes': m.notes,
        'aiConfidence': m.aiConfidence,
        'userEdited': m.userEdited,
        'totalCalories': m.totalCalories,
        'totalProteinG': m.totalProteinG,
        'totalCarbsG': m.totalCarbsG,
        'totalFatG': m.totalFatG,
        'totalSugarG': m.totalSugarG,
        'totalSodiumMg': m.totalSodiumMg,
        'isFavorite': m.isFavorite,
        'items': m.items.map(_itemToMap).toList(),
      };

  Map<String, dynamic> _itemToMap(MealItem i) => {
        'name': i.name,
        'servingDescription': i.servingDescription,
        'estimatedWeightG': i.estimatedWeightG,
        'calories': i.calories,
        'proteinG': i.proteinG,
        'carbsG': i.carbsG,
        'fatG': i.fatG,
        'sugarG': i.sugarG,
        'sodiumMg': i.sodiumMg,
      };

  Meal _mealFromMap(Map<String, dynamic> m, String imagesDir) {
    final meal = Meal();
    if (m['id'] != null && m['id'] is int) {
      meal.id = m['id'] as int;
    }
    meal
      ..createdAt = DateTime.parse(m['createdAt'] as String)
      ..updatedAt = DateTime.parse(m['updatedAt'] as String)
      ..date = DateTime.parse(m['date'] as String)
      ..time = m['time'] as String
      ..mealType = MealType.values[m['mealType'] as int]
      ..originalUserInput = m['originalUserInput'] as String
      ..aiInterpretation = m['aiInterpretation'] as String?
      ..notes = m['notes'] as String?
      ..aiConfidence = (m['aiConfidence'] as num? ?? 0).toDouble()
      ..userEdited = m['userEdited'] as bool? ?? false
      ..totalCalories = (m['totalCalories'] as num? ?? 0).toDouble()
      ..totalProteinG = (m['totalProteinG'] as num? ?? 0).toDouble()
      ..totalCarbsG = (m['totalCarbsG'] as num? ?? 0).toDouble()
      ..totalFatG = (m['totalFatG'] as num? ?? 0).toDouble()
      ..totalSugarG = (m['totalSugarG'] as num? ?? 0).toDouble()
      ..totalSodiumMg = (m['totalSodiumMg'] as num? ?? 0).toDouble()
      ..isFavorite = m['isFavorite'] as bool? ?? false
      ..items = ((m['items'] as List?) ?? [])
          .map((i) => _itemFromMap(i as Map<String, dynamic>))
          .toList();

    final origPath = m['imagePath'] as String?;
    if (origPath != null) {
      final filename = origPath.split(Platform.pathSeparator).last;
      meal.imagePath = '$imagesDir/$filename';
    }
    return meal;
  }

  MealItem _itemFromMap(Map<String, dynamic> i) => MealItem()
    ..name = i['name'] as String? ?? ''
    ..servingDescription = i['servingDescription'] as String? ?? ''
    ..estimatedWeightG = (i['estimatedWeightG'] as num? ?? 0).toDouble()
    ..calories = (i['calories'] as num? ?? 0).toDouble()
    ..proteinG = (i['proteinG'] as num? ?? 0).toDouble()
    ..carbsG = (i['carbsG'] as num? ?? 0).toDouble()
    ..fatG = (i['fatG'] as num? ?? 0).toDouble()
    ..sugarG = (i['sugarG'] as num? ?? 0).toDouble()
    ..sodiumMg = (i['sodiumMg'] as num? ?? 0).toDouble();

  Map<String, dynamic> _settingsToMap(AppSettings s) => {
        'goalCalories': s.goalCalories,
        'goalProteinG': s.goalProteinG,
        'goalCarbsG': s.goalCarbsG,
        'goalFatG': s.goalFatG,
        'heightCm': s.heightCm,
        'weightKg': s.weightKg,
        'ageYears': s.ageYears,
        'gender': s.gender,
        'activityLevelIndex': s.activityLevelIndex,
        'targetWeightKg': s.targetWeightKg,
        'weeklyRateKg': s.weeklyRateKg,
        'themeModeIndex': s.themeModeIndex,
        'isMaterial3Expressive': s.isMaterial3Expressive,
        'customColorName': s.customColorName,
        'customColorValue': s.customColorValue,
        'useMetric': s.useMetric,
        'imageQuality': s.imageQuality,
      };

  void _applySettingsMap(AppSettings s, Map<String, dynamic> m) {
    s.goalCalories = (m['goalCalories'] as num? ?? s.goalCalories).toDouble();
    s.goalProteinG = (m['goalProteinG'] as num? ?? s.goalProteinG).toDouble();
    s.goalCarbsG = (m['goalCarbsG'] as num? ?? s.goalCarbsG).toDouble();
    s.goalFatG = (m['goalFatG'] as num? ?? s.goalFatG).toDouble();
    s.heightCm = (m['heightCm'] as num? ?? s.heightCm).toDouble();
    s.weightKg = (m['weightKg'] as num? ?? s.weightKg).toDouble();
    s.ageYears = m['ageYears'] as int? ?? s.ageYears;
    s.gender = m['gender'] as String? ?? s.gender;
    s.activityLevelIndex =
        m['activityLevelIndex'] as int? ?? s.activityLevelIndex;
    s.targetWeightKg =
        (m['targetWeightKg'] as num? ?? s.targetWeightKg).toDouble();
    s.weeklyRateKg = (m['weeklyRateKg'] as num? ?? s.weeklyRateKg).toDouble();
    s.themeModeIndex = m['themeModeIndex'] as int? ?? s.themeModeIndex;
    s.isMaterial3Expressive =
        m['isMaterial3Expressive'] as bool? ?? s.isMaterial3Expressive;
    s.customColorName = m['customColorName'] as String? ?? s.customColorName;
    s.customColorValue = m['customColorValue'] as int? ?? s.customColorValue;
    s.useMetric = m['useMetric'] as bool? ?? s.useMetric;
    s.imageQuality = m['imageQuality'] as int? ?? s.imageQuality;
  }
}

class _ExportScopeSheet extends StatelessWidget {
  const _ExportScopeSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Export Data',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose whether to export your complete history or meals within a date range.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            tileColor: cs.surfaceContainerLow,
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.storage_rounded, color: cs.primary),
            ),
            title: const Text(
              'Export All Data',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Export complete meal history, settings & images'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(ExportScope.all);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            tileColor: cs.surfaceContainerLow,
            leading: CircleAvatar(
              backgroundColor: cs.tertiaryContainer,
              child: Icon(Icons.date_range_rounded, color: cs.tertiary),
            ),
            title: const Text(
              'Export Specific Date Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle:
                const Text('Export meals in range, settings & associated images'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(ExportScope.dateRange);
            },
          ),
        ],
      ),
    );
  }
}

class _ImportOptionsDialog extends StatefulWidget {
  const _ImportOptionsDialog();

  @override
  State<_ImportOptionsDialog> createState() => _ImportOptionsDialogState();
}

class _ImportOptionsDialogState extends State<_ImportOptionsDialog> {
  bool _importMeals = true;
  bool _importSettings = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canImport = _importMeals || _importSettings;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: const Row(
        children: [
          Icon(Icons.download_rounded),
          SizedBox(width: 10),
          Text('Import Options'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select what you want to import from this backup file:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _importMeals,
            onChanged: (val) {
              if (val != null) setState(() => _importMeals = val);
            },
            title: const Text(
              'Meal History & Data',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Meals, food items & photo logs'),
            secondary: Icon(Icons.restaurant_rounded, color: cs.primary),
            contentPadding: EdgeInsets.zero,
            activeColor: cs.primary,
          ),
          CheckboxListTile(
            value: _importSettings,
            onChanged: (val) {
              if (val != null) setState(() => _importSettings = val);
            },
            title: const Text(
              'Settings & Daily Goals',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Daily macros, goals & personal profile'),
            secondary: Icon(Icons.settings_rounded, color: cs.tertiary),
            contentPadding: EdgeInsets.zero,
            activeColor: cs.primary,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: cs.outline.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: canImport
                    ? () => Navigator.of(context).pop(
                          ImportOptions(
                            importMeals: _importMeals,
                            importSettings: _importSettings,
                          ),
                        )
                    : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Import'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
