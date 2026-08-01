import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/models/meal.dart';
import 'core/models/app_settings.dart';
import 'core/database/isar_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional load env
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (_) {}

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init Isar
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [MealSchema, AppSettingsSchema],
    directory: dir.path,
  );
  IsarService.init(isar);

  // Init Notifications (11 AM morning check-in, 6h inactivity, 11 PM - 8 AM quiet hours)
  NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: BiteApp(),
    ),
  );
}
