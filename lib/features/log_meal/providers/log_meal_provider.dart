import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ai/gemini_service.dart';
import '../../../core/database/isar_service.dart';
import '../../../core/models/meal.dart';
import '../../../core/services/notification_service.dart';

part 'log_meal_provider.g.dart';

enum LogMealStatus { idle, analyzing, needsClarification, success, error }

class LogMealState {
  final LogMealStatus status;
  final MealAnalysisResult? result;
  final String? errorMessage;
  final String? clarificationQuestion;
  final String inputMode; // 'text' | 'camera'

  const LogMealState({
    this.status = LogMealStatus.idle,
    this.result,
    this.errorMessage,
    this.clarificationQuestion,
    this.inputMode = 'text',
  });

  LogMealState copyWith({
    LogMealStatus? status,
    MealAnalysisResult? result,
    String? errorMessage,
    String? clarificationQuestion,
    String? inputMode,
  }) =>
      LogMealState(
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        clarificationQuestion:
            clarificationQuestion ?? this.clarificationQuestion,
        inputMode: inputMode ?? this.inputMode,
      );
}

@riverpod
class LogMealNotifier extends _$LogMealNotifier {
  @override
  LogMealState build() => const LogMealState();

  Future<void> analyze({String? text, List<int>? imageBytes}) async {
    state = state.copyWith(status: LogMealStatus.analyzing);
    try {
      final result = await GeminiService.instance.analyzeMeal(
        text: text,
        imageBytes: imageBytes != null
            ? Uint8List.fromList(imageBytes)
            : null,
      );
      if (result.needsClarification) {
        state = state.copyWith(
          status: LogMealStatus.needsClarification,
          result: result,
          clarificationQuestion: result.clarificationQuestion,
        );
      } else {
        state = state.copyWith(
          status: LogMealStatus.success,
          result: result,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: LogMealStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<int> saveMeal({
    required String originalInput,
    required MealAnalysisResult result,
    String? imagePath,
    DateTime? targetDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = targetDate ?? now;
    final mealDate = DateTime(d.year, d.month, d.day);
    final isDifferentDay = mealDate.difference(today).inDays != 0;

    final DateTime createdAt;
    final String timeStr;
    final MealType mealType;

    if (isDifferentDay) {
      createdAt = DateTime(d.year, d.month, d.day, 0, 0, 0);
      timeStr = "00:00";
      mealType = MealType.breakfast;
    } else {
      createdAt = DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second);
      timeStr = _formatTime(now);
      mealType = MealType.fromTime(now);
    }

    final meal = Meal()
      ..createdAt = createdAt
      ..updatedAt = now
      ..date = mealDate
      ..time = timeStr
      ..mealType = mealType
      ..originalUserInput = originalInput
      ..aiInterpretation = result.mealName
      ..aiConfidence = result.confidence
      ..imagePath = imagePath
      ..items = result.items
      ..userEdited = false;
    meal.recalculateTotals();
    final id = await isarService.saveMeal(meal);
    NotificationService.instance.updateSchedule();
    return id;
  }

  void reset() => state = const LogMealState();
  void setResult(MealAnalysisResult res) =>
      state = state.copyWith(status: LogMealStatus.success, result: res);
  void setInputMode(String mode) =>
      state = state.copyWith(inputMode: mode);

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
