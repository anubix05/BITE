import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../database/isar_service.dart';
import '../models/meal.dart';

/// Result from Gemini analysis
class MealAnalysisResult {
  final String mealName;
  final double confidence;
  final bool needsClarification;
  final String? clarificationQuestion;
  final List<MealItem> items;
  final String rawJson;

  const MealAnalysisResult({
    required this.mealName,
    required this.confidence,
    required this.needsClarification,
    this.clarificationQuestion,
    required this.items,
    required this.rawJson,
  });

  double get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProtein => items.fold(0, (s, i) => s + i.proteinG);
  double get totalCarbs => items.fold(0, (s, i) => s + i.carbsG);
  double get totalFat => items.fold(0, (s, i) => s + i.fatG);
}

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const List<String> _candidateModels = [
    'gemini-flash-latest',
    'gemini-2.0-flash',
    'gemini-2.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-pro-latest',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  String? _workingModelName;

  /// Checks if a valid Gemini API key is configured either in settings, parameter, or dotenv.
  Future<bool> hasApiKey({String? apiKeyOverride}) async {
    String? settingsKey;
    try {
      final settings = await isarService.getOrCreateSettings();
      if (settings.geminiApiKeyOverride?.trim().isNotEmpty == true) {
        settingsKey = settings.geminiApiKeyOverride!.trim();
      }
    } catch (_) {}

    final key = (apiKeyOverride?.trim().isNotEmpty == true ? apiKeyOverride!.trim() : null) ??
        settingsKey ??
        dotenv.env['GEMINI_API_KEY']?.trim() ??
        '';

    return key.isNotEmpty && key != 'YOUR_GEMINI_API_KEY_HERE';
  }

  /// Analyse a meal from text and/or image with automatic model fallback.
  Future<MealAnalysisResult> analyzeMeal({
    String? text,
    Uint8List? imageBytes,
    String? apiKeyOverride,
  }) async {
    String? settingsKey;
    try {
      final settings = await isarService.getOrCreateSettings();
      if (settings.geminiApiKeyOverride?.trim().isNotEmpty == true) {
        settingsKey = settings.geminiApiKeyOverride!.trim();
      }
    } catch (_) {
      // DB not initialized in headless tests
    }

    final key = (apiKeyOverride?.trim().isNotEmpty == true ? apiKeyOverride!.trim() : null) ??
        settingsKey ??
        dotenv.env['GEMINI_API_KEY']?.trim() ??
        '';

    if (key.isEmpty || key == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception(
          'Gemini API key is not configured. Please add your API key in Settings -> AI Settings.');
    }

    final prompt = _buildPrompt(text: text);
    final partsPayload = <Map<String, dynamic>>[
      {'text': prompt}
    ];

    if (imageBytes != null) {
      partsPayload.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(imageBytes),
        }
      });
    }

    final requestBody = {
      'contents': [
        {'parts': partsPayload}
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      }
    };

    final modelsToTry = <String>[];
    if (_workingModelName != null) modelsToTry.add(_workingModelName!);
    for (final m in _candidateModels) {
      if (!modelsToTry.contains(m)) modelsToTry.add(m);
    }

    Object? lastError;

    for (final modelName in modelsToTry) {
      final urls = [
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$key',
        'https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent?key=$key',
      ];

      for (final url in urls) {
        try {
          final response = await _dio.post(
            url,
            data: requestBody,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data is String
                ? jsonDecode(response.data as String)
                : response.data;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final contentMap =
                  candidates[0]['content'] as Map<String, dynamic>?;
              final partsList = contentMap?['parts'] as List<dynamic>?;
              if (partsList != null && partsList.isNotEmpty) {
                final rawText = partsList[0]['text'] as String?;
                if (rawText != null && rawText.isNotEmpty) {
                  _workingModelName = modelName;
                  return _parseResponse(rawText);
                }
              }
            }
          }
        } catch (e) {
          lastError = e;
          if (e is DioException && e.response?.data != null) {
            lastError = e.response?.data;
          }
        }
      }

      // 2. Fallback to GenerativeModel SDK
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1,
          ),
        );
        final sdkParts = <Part>[TextPart(prompt)];
        if (imageBytes != null) sdkParts.add(DataPart('image/jpeg', imageBytes));
        final response = await model.generateContent([Content.multi(sdkParts)]);
        final raw = response.text ?? '';
        if (raw.isNotEmpty) {
          _workingModelName = modelName;
          return _parseResponse(raw);
        }
      } catch (e) {
        lastError = e;
      }
    }

    _workingModelName = null; // Reset cached working model on failure so next request tries full list afresh

    final errStr = lastError.toString();
    if (errStr.contains('API restriction') || errStr.contains('1 API') || errStr.contains('NOT_FOUND') || errStr.contains('not found')) {
      throw Exception(
          'API Key Restriction Error:\nYour key is restricted to "Gemini API" (Vertex AI) instead of "Generative Language API".\n\nFix in Google Cloud Console:\n1. Open your API key credentials page.\n2. Under "Select API restrictions", change it to "Don\'t restrict key" (or add "Generative Language API").\n3. Click Save.');
    }

    throw Exception(
        'Gemini API Key Error: Please verify your API key in Settings -> AI Settings.\nDetails: $lastError');
  }

  String _buildPrompt({String? text}) {
    return '''
You are a precise nutrition analysis AI. Analyse the following meal description and return ONLY valid JSON — no markdown, no explanation.

Meal description: "${text ?? 'See attached image'}"

Return JSON matching this EXACT schema:
{
  "mealName": "string — concise meal name",
  "confidence": 0.0-1.0,
  "needsClarification": boolean,
  "clarificationQuestion": "string or null",
  "items": [
    {
      "name": "string",
      "servingDescription": "string e.g. '1 full plate'",
      "estimatedWeightG": number,
      "calories": number,
      "proteinG": number,
      "carbsG": number,
      "fatG": number,
      "sugarG": number,
      "sodiumMg": number
    }
  ]
}

Rules:
- ALL nutritional values must be numbers (never null).
- Use realistic Indian/global food database values.
- If the user says "one plate" assume ~400-600g typical serving.
- If unsure of portion, set confidence < 0.7 and set needsClarification = true.
- Return only JSON. No other text.
''';
  }

  MealAnalysisResult _parseResponse(String raw) {
    try {
      // Strip any accidental markdown fences
      var clean = raw.trim();
      if (clean.startsWith('```')) {
        clean = clean.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
      }

      final json = jsonDecode(clean) as Map<String, dynamic>;

      final itemsJson = json['items'] as List<dynamic>? ?? [];
      final List<MealItem> items;
      if (itemsJson.isNotEmpty) {
        items = itemsJson.map((e) {
          final m = e as Map<String, dynamic>;
          final item = MealItem()
            ..name = m['name'] as String? ?? (json['mealName'] as String? ?? 'Meal Item')
            ..servingDescription = m['servingDescription'] as String? ?? '1 serving'
            ..estimatedWeightG = (m['estimatedWeightG'] as num?)?.toDouble() ?? 0
            ..calories = (m['calories'] as num?)?.toDouble() ?? 0
            ..proteinG = (m['proteinG'] as num?)?.toDouble() ?? 0
            ..carbsG = (m['carbsG'] as num?)?.toDouble() ?? 0
            ..fatG = (m['fatG'] as num?)?.toDouble() ?? 0
            ..sugarG = (m['sugarG'] as num?)?.toDouble() ?? 0
            ..sodiumMg = (m['sodiumMg'] as num?)?.toDouble() ?? 0;
          item.aiCalories = item.calories;
          item.aiProteinG = item.proteinG;
          item.aiCarbsG = item.carbsG;
          item.aiFatG = item.fatG;
          return item;
        }).toList();
      } else {
        final mealName = json['mealName'] as String? ?? 'Meal Item';
        final item = MealItem()
          ..name = mealName
          ..servingDescription = '1 serving'
          ..calories = (json['totalCalories'] as num?)?.toDouble() ?? (json['calories'] as num?)?.toDouble() ?? 450
          ..proteinG = (json['totalProtein'] as num?)?.toDouble() ?? (json['proteinG'] as num?)?.toDouble() ?? 20
          ..carbsG = (json['totalCarbs'] as num?)?.toDouble() ?? (json['carbsG'] as num?)?.toDouble() ?? 50
          ..fatG = (json['totalFat'] as num?)?.toDouble() ?? (json['fatG'] as num?)?.toDouble() ?? 15;
        item.aiCalories = item.calories;
        item.aiProteinG = item.proteinG;
        item.aiCarbsG = item.carbsG;
        item.aiFatG = item.fatG;
        items = [item];
      }

      return MealAnalysisResult(
        mealName: json['mealName'] as String? ?? 'Meal',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        needsClarification: json['needsClarification'] as bool? ?? false,
        clarificationQuestion: json['clarificationQuestion'] as String?,
        items: items,
        rawJson: raw,
      );
    } catch (e) {
      throw Exception('Failed to parse Gemini response: $e\nRaw: $raw');
    }
  }
}

/// Shows a user-friendly alert dialog when the Gemini API key is missing.
Future<void> showApiKeyMissingDialog(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(Icons.key_off_rounded, size: 36, color: Colors.amber),
      title: const Text('Gemini API Key Required', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A free Gemini API key is needed to use AI food recognition and natural language parsing.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mini Setup Guide:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text('1. Tap below to open Google AI Studio in browser.', style: TextStyle(fontSize: 12)),
                  const Text('2. Sign in with Google & tap "Create API Key".', style: TextStyle(fontSize: 12)),
                  const Text('3. Copy your key and paste it in Settings.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 10),
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
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open Google AI Studio ↗', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
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
                onPressed: () => Navigator.of(ctx).pop(),
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
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pushNamed('settings');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Go to Settings'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
