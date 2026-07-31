import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/isar_service.dart';
import '../models/meal.dart';
import '../models/app_settings.dart';

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  // ─────────────── EXPORT ───────────────

  Future<void> exportBackup(BuildContext context) async {
    try {
      final meals = await isarService.getAllMeals(limit: 999999);
      final settings = await isarService.getOrCreateSettings();

      final mealsJson = jsonEncode(meals.map(_mealToMap).toList());
      final settingsJson = jsonEncode(_settingsToMap(settings));
      final versionJson = jsonEncode({
        'version': '1.3.0',
        'exportedAt': DateTime.now().toIso8601String(),
      });

      final archive = Archive();
      archive.addFile(ArchiveFile(
          'meals.json', mealsJson.length, utf8.encode(mealsJson)));
      archive.addFile(ArchiveFile(
          'settings.json', settingsJson.length, utf8.encode(settingsJson)));
      archive.addFile(ArchiveFile(
          'version.json', versionJson.length, utf8.encode(versionJson)));

      for (final meal in meals) {
        if (meal.imagePath != null) {
          final file = File(meal.imagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final name =
                'images/${meal.id}_${file.uri.pathSegments.last}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup saved successfully! 🎉'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Import Backup?'),
        content: const Text(
          'This will replace any matching meals with the data from the backup file and add new ones. '
          'Existing meals in the app that are not in the backup will be retained.',
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
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary,
                    foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
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
      ),
    );
    if (confirmed != true) return;

    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/meal_images');
      if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

      for (final file in archive) {
        if (file.name.startsWith('images/') && file.isFile) {
          final outPath =
              '${imagesDir.path}/${file.name.split('/').last}';
          await File(outPath)
              .writeAsBytes(file.content as List<int>);
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

        final mealsData = jsonDecode(
            utf8.decode(mealsFile.content as List<int>)) as List;

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

      final settingsFile = archive.findFile('settings.json');
      if (settingsFile != null) {
        final settingsData = jsonDecode(
                utf8.decode(settingsFile.content as List<int>))
            as Map<String, dynamic>;
        final current = await isarService.getOrCreateSettings();
        _applySettingsMap(current, settingsData);
        await isarService.saveSettings(current);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup imported successfully ✅'),
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
      ..aiConfidence =
          (m['aiConfidence'] as num? ?? 0).toDouble()
      ..userEdited = m['userEdited'] as bool? ?? false
      ..totalCalories =
          (m['totalCalories'] as num? ?? 0).toDouble()
      ..totalProteinG =
          (m['totalProteinG'] as num? ?? 0).toDouble()
      ..totalCarbsG = (m['totalCarbsG'] as num? ?? 0).toDouble()
      ..totalFatG = (m['totalFatG'] as num? ?? 0).toDouble()
      ..totalSugarG =
          (m['totalSugarG'] as num? ?? 0).toDouble()
      ..totalSodiumMg =
          (m['totalSodiumMg'] as num? ?? 0).toDouble()
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
    ..estimatedWeightG =
        (i['estimatedWeightG'] as num? ?? 0).toDouble()
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
        'themeModeIndex': s.themeModeIndex,
        'isMaterial3Expressive': s.isMaterial3Expressive,
        'customColorName': s.customColorName,
        'customColorValue': s.customColorValue,
        'useMetric': s.useMetric,
        'imageQuality': s.imageQuality,
      };

  void _applySettingsMap(AppSettings s, Map<String, dynamic> m) {
    s.goalCalories =
        (m['goalCalories'] as num? ?? s.goalCalories).toDouble();
    s.goalProteinG =
        (m['goalProteinG'] as num? ?? s.goalProteinG).toDouble();
    s.goalCarbsG =
        (m['goalCarbsG'] as num? ?? s.goalCarbsG).toDouble();
    s.goalFatG =
        (m['goalFatG'] as num? ?? s.goalFatG).toDouble();
    s.themeModeIndex =
        m['themeModeIndex'] as int? ?? s.themeModeIndex;
    s.isMaterial3Expressive =
        m['isMaterial3Expressive'] as bool? ?? s.isMaterial3Expressive;
    s.customColorName =
        m['customColorName'] as String? ?? s.customColorName;
    s.customColorValue =
        m['customColorValue'] as int? ?? s.customColorValue;
    s.useMetric = m['useMetric'] as bool? ?? s.useMetric;
    s.imageQuality =
        m['imageQuality'] as int? ?? s.imageQuality;
  }
}

