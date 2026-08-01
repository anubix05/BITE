import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/isar_service.dart';
import '../../core/services/nutrition_calculator.dart';
import '../../core/widgets/expressive_slider.dart';
import '../settings/providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Personal Info State
  String _gender = 'Male';
  int _ageYears = 25;
  double _heightCm = 170.0;
  double _weightKg = 70.0;
  int _activityIndex = 1; // Lightly Active

  // Goal State
  double _targetWeightKg = 70.0;
  double _weeklyRateKg = 0.5;

  // AI Setup State
  final TextEditingController _apiKeyController = TextEditingController();
  bool _showApiKey = false;

  // Permissions State
  bool _cameraGranted = false;
  bool _photosGranted = false;
  bool _notificationsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final camera = await Permission.camera.status;
      final photos = await Permission.photos.status;
      final storage = await Permission.storage.status;
      final notifications = await Permission.notification.status;

      if (mounted) {
        setState(() {
          _cameraGranted = camera.isGranted;
          _photosGranted = photos.isGranted || storage.isGranted;
          _notificationsGranted = notifications.isGranted;
        });
      }
    } catch (_) {}
  }

  Future<void> _requestCameraPermission() async {
    HapticFeedback.lightImpact();
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() => _cameraGranted = status.isGranted);
    }
  }

  Future<void> _requestPhotosPermission() async {
    HapticFeedback.lightImpact();
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (mounted) {
      setState(() => _photosGranted = status.isGranted);
    }
  }

  Future<void> _requestNotificationsPermission() async {
    HapticFeedback.lightImpact();
    final status = await Permission.notification.request();
    if (mounted) {
      setState(() => _notificationsGranted = status.isGranted);
    }
  }

  Future<void> _requestAllPermissions() async {
    HapticFeedback.mediumImpact();
    await _requestCameraPermission();
    await _requestPhotosPermission();
    await _requestNotificationsPermission();
  }

  Future<void> _launchAiStudio() async {
    final uri = Uri.parse('https://aistudio.google.com/app/apikey');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copied to clipboard! Paste in browser to get key. 📋'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding({required bool saveApiKey}) async {
    final result = NutritionCalculator.calculateTargets(
      heightCm: _heightCm,
      weightKg: _weightKg,
      ageYears: _ageYears,
      gender: _gender,
      activityLevelIndex: _activityIndex,
      targetWeightKg: _targetWeightKg,
      weeklyRateKg: _weeklyRateKg,
    );

    final settings = await isarService.getOrCreateSettings();
    settings.onboardingComplete = true;
    settings.gender = _gender;
    settings.ageYears = _ageYears;
    settings.heightCm = _heightCm;
    settings.weightKg = _weightKg;
    settings.activityLevelIndex = _activityIndex;
    settings.targetWeightKg = _targetWeightKg;
    settings.weeklyRateKg = _weeklyRateKg;

    // Apply calculated nutrition goals
    settings.goalCalories = result.targetCalories;
    settings.goalProteinG = result.targetProteinG;
    settings.goalCarbsG = result.targetCarbsG;
    settings.goalFatG = result.targetFatG;

    if (saveApiKey && _apiKeyController.text.trim().isNotEmpty) {
      settings.geminiApiKeyOverride = _apiKeyController.text.trim();
    }

    await isarService.saveSettings(settings);
    ref.invalidate(settingsNotifierProvider);
    ref.invalidate(appSettingsProvider);

    if (mounted) {
      context.goNamed('dashboard');
    }
  }

  void _showManualNumberDialog({
    required String title,
    required String label,
    required double initialValue,
    required double min,
    required double max,
    required ValueChanged<double> onSaved,
  }) {
    final controller = TextEditingController(
      text: initialValue.toStringAsFixed(initialValue == initialValue.roundToDouble() ? 0 : 1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= min && val <= max) {
                onSaved(val);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _previousPage,
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Step ${_currentPage + 1} of 5',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_currentPage + 1) / 5.0,
                            minHeight: 6,
                            backgroundColor: cs.primaryContainer.withValues(alpha: 0.3),
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _completeOnboarding(saveApiKey: false),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildWelcomeStep(cs),
                  _buildPersonalInfoStep(cs),
                  _buildGoalCalculatorStep(cs),
                  _buildPermissionsStep(cs),
                  _buildAiGuideStep(cs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── STEP 0: WELCOME ───────────────

  Widget _buildWelcomeStep(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return SvgPicture.asset(
                  isDark
                      ? 'assets/images/bite_logo_white_transparent.svg'
                      : 'assets/images/bite_logo_black_transparent.svg',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to Bite',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Describe what you ate.\nLet AI do the rest.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 20),
          ...[
            (
              Icons.chat_bubble_outline_rounded,
              'Natural language logging',
              'Just type "one plate biryani" — no tedious forms'
            ),
            (
              Icons.camera_alt_outlined,
              'Photo recognition',
              'Snap a photo and AI identifies food & portion sizes'
            ),
            (
              Icons.palette_outlined,
              'Expressive Theme Customization',
              'Sleek Monochrome theme by default + 9 custom accent colors & Dark Mode'
            ),
            (
              Icons.shield_outlined,
              'Local-first & Private',
              '100% of your history stays safely on your device'
            ),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$1, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
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
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────── STEP 1: PERSONAL DETAILS & BMI ───────────────

  Widget _buildPersonalInfoStep(ColorScheme cs) {
    final bmr = NutritionCalculator.calculateBmr(
      heightCm: _heightCm,
      weightKg: _weightKg,
      ageYears: _ageYears,
      gender: _gender,
    );
    final validActivity = _activityIndex.clamp(0, NutritionCalculator.activityMultipliers.length - 1);
    final tdee = bmr * NutritionCalculator.activityMultipliers[validActivity];
    final bmiResult = NutritionCalculator.calculateBmi(
      heightCm: _heightCm,
      weightKg: _weightKg,
    );

    Color bmiColor;
    switch (bmiResult.category) {
      case 'Underweight':
        bmiColor = Colors.orange;
        break;
      case 'Normal weight':
        bmiColor = Colors.green;
        break;
      case 'Overweight':
        bmiColor = Colors.deepOrange;
        break;
      default:
        bmiColor = Colors.red;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Details',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us about yourself to compute your baseline BMI & daily energy expenditure.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Biological Sex
          const Text('Biological Sex', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Male', label: Text('Male'), icon: Icon(Icons.male_rounded)),
              ButtonSegment(value: 'Female', label: Text('Female'), icon: Icon(Icons.female_rounded)),
            ],
            selected: {_gender},
            onSelectionChanged: (val) => setState(() => _gender = val.first),
          ),
          const SizedBox(height: 16),

          // Age
          _buildMetricSliderTile(
            cs: cs,
            title: 'Age',
            valueText: '$_ageYears years',
            value: _ageYears.toDouble(),
            min: 15,
            max: 90,
            onChanged: (val) => setState(() => _ageYears = val.round()),
            onEditTap: () => _showManualNumberDialog(
              title: 'Enter Age',
              label: 'Age (years)',
              initialValue: _ageYears.toDouble(),
              min: 15,
              max: 90,
              onSaved: (val) => setState(() => _ageYears = val.round()),
            ),
          ),
          const SizedBox(height: 12),

          // Height
          _buildMetricSliderTile(
            cs: cs,
            title: 'Height',
            valueText: '${_heightCm.toStringAsFixed(1)} cm',
            value: _heightCm,
            min: 120,
            max: 220,
            onChanged: (val) => setState(() => _heightCm = val),
            onEditTap: () => _showManualNumberDialog(
              title: 'Enter Height',
              label: 'Height (cm)',
              initialValue: _heightCm,
              min: 120,
              max: 220,
              onSaved: (val) => setState(() => _heightCm = val),
            ),
          ),
          const SizedBox(height: 12),

          // Weight
          _buildMetricSliderTile(
            cs: cs,
            title: 'Current Weight',
            valueText: '${_weightKg.toStringAsFixed(1)} kg',
            value: _weightKg,
            min: 30,
            max: 200,
            onChanged: (val) => setState(() => _weightKg = val),
            onEditTap: () => _showManualNumberDialog(
              title: 'Enter Weight',
              label: 'Weight (kg)',
              initialValue: _weightKg,
              min: 30,
              max: 200,
              onSaved: (val) => setState(() => _weightKg = val),
            ),
          ),
          const SizedBox(height: 16),

          // Activity Level
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
              final isSelected = _activityIndex == index;
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
                      setState(() => _activityIndex = index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: index,
                            // ignore: deprecated_member_use
                            groupValue: _activityIndex,
                            // ignore: deprecated_member_use
                            onChanged: (val) {
                              if (val != null) {
                                HapticFeedback.selectionClick();
                                setState(() => _activityIndex = val);
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
          const SizedBox(height: 20),

          // BMI & Metabolism Summary Card
          Card(
            elevation: 0,
            color: cs.primaryContainer.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Body Mass Index (BMI)', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${bmiResult.bmi}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: bmiColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: bmiColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  bmiResult.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: bmiColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryMetric('BMR (Basal Rate)', '${bmr.round()} kcal/day'),
                      _buildSummaryMetric('TDEE (Daily Total)', '${tdee.round()} kcal/day'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next: Set Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────── STEP 2: GOAL CALCULATOR ───────────────

  Widget _buildGoalCalculatorStep(ColorScheme cs) {
    final targets = NutritionCalculator.calculateTargets(
      heightCm: _heightCm,
      weightKg: _weightKg,
      ageYears: _ageYears,
      gender: _gender,
      activityLevelIndex: _activityIndex,
      targetWeightKg: _targetWeightKg,
      weeklyRateKg: _weeklyRateKg,
    );

    String goalTitle;
    Color goalColor;
    if (targets.goalType == 'loss') {
      goalTitle = 'Weight Loss';
      goalColor = cs.primary;
    } else if (targets.goalType == 'gain') {
      goalTitle = 'Weight Gain';
      goalColor = cs.tertiary;
    } else {
      goalTitle = 'Weight Maintenance';
      goalColor = Colors.green;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight Goal & Targets',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your target weight and weekly pace to calculate daily calories & macros.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Target Weight Slider
          _buildMetricSliderTile(
            cs: cs,
            title: 'Target Weight Goal',
            valueText: '${_targetWeightKg.toStringAsFixed(1)} kg',
            value: _targetWeightKg,
            min: 30,
            max: 200,
            onChanged: (val) => setState(() => _targetWeightKg = val),
            onEditTap: () => _showManualNumberDialog(
              title: 'Enter Target Weight',
              label: 'Target Weight (kg)',
              initialValue: _targetWeightKg,
              min: 30,
              max: 200,
              onSaved: (val) => setState(() => _targetWeightKg = val),
            ),
          ),
          const SizedBox(height: 16),

          // Goal Category Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: goalColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: goalColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  targets.goalType == 'loss'
                      ? Icons.trending_down_rounded
                      : targets.goalType == 'gain'
                          ? Icons.trending_up_rounded
                          : Icons.trending_flat_rounded,
                  color: goalColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goalTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: goalColor,
                        ),
                      ),
                      Text(
                        targets.goalType == 'maintain'
                          ? 'Maintain current weight of ${_weightKg.toStringAsFixed(1)} kg'
                          : 'Target: ${_targetWeightKg.toStringAsFixed(1)} kg (Current: ${_weightKg.toStringAsFixed(1)} kg)',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Weekly Rate Selector (Only for loss or gain)
          if (targets.goalType != 'maintain') ...[
            Text(
              targets.goalType == 'loss' ? 'Weekly Loss Pace' : 'Weekly Gain Pace',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.25, label: Text('0.25 kg/wk')),
                ButtonSegment(value: 0.50, label: Text('0.50 kg/wk')),
                ButtonSegment(value: 1.00, label: Text('1.00 kg/wk')),
              ],
              selected: {_weeklyRateKg},
              onSelectionChanged: (val) => setState(() => _weeklyRateKg = val.first),
            ),
            const SizedBox(height: 20),
          ],

          // Calculated Daily Targets Card
          Card(
            elevation: 0,
            color: cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recommended Daily Target',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${targets.targetCalories.round()} kcal/day',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroBadge('Protein (30%)', '${targets.targetProteinG.round()} g', cs.primary),
                      _buildMacroBadge('Carbs (45%)', '${targets.targetCarbsG.round()} g', cs.secondary),
                      _buildMacroBadge('Fat (25%)', '${targets.targetFatG.round()} g', cs.tertiary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next: Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────── STEP 3: APP PERMISSIONS ───────────────

  Widget _buildPermissionsStep(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Permissions',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Grant permissions for food photo analysis, gallery imports, and check-in reminders.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Permission 1: Camera
          _buildPermissionTile(
            cs: cs,
            icon: Icons.camera_alt_rounded,
            title: 'Camera Access',
            subtitle: 'Snap food photos directly in Bite for instant AI meal analysis.',
            isGranted: _cameraGranted,
            onRequest: _requestCameraPermission,
          ),
          const SizedBox(height: 12),

          // Permission 2: Photo Library / Storage
          _buildPermissionTile(
            cs: cs,
            icon: Icons.photo_library_rounded,
            title: 'Photo Library',
            subtitle: 'Choose existing meal photos from your gallery for AI parsing.',
            isGranted: _photosGranted,
            onRequest: _requestPhotosPermission,
          ),
          const SizedBox(height: 12),

          // Permission 3: Notifications
          _buildPermissionTile(
            cs: cs,
            icon: Icons.notifications_active_rounded,
            title: 'Check-in Reminders',
            subtitle: 'Receive quiet daily notifications to log your meals & stay on track.',
            isGranted: _notificationsGranted,
            onRequest: _requestNotificationsPermission,
          ),
          const SizedBox(height: 24),

          if (!_cameraGranted || !_photosGranted || !_notificationsGranted) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _requestAllPermissions,
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Grant All Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next: AI Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required ColorScheme cs,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Material(
      color: isGranted ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isGranted ? null : onRequest,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGranted ? cs.primary.withValues(alpha: 0.15) : cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isGranted ? cs.primary : cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isGranted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Given',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                FilledButton.tonal(
                  onPressed: onRequest,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── STEP 3: GEMINI AI SETUP GUIDE ───────────────

  Widget _buildAiGuideStep(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gemini AI Setup',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Bite uses Google\'s free Gemini 2.5 Flash API to parse meal text and food photos.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Guide Card
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to get your free Gemini API Key:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep('1', 'Tap below to open Google AI Studio in your browser:'),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 8, bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: _launchAiStudio,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'Open Google AI Studio ↗',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  _buildGuideStep('2', 'Sign in with your Google account & tap "Create API Key"'),
                  const SizedBox(height: 6),
                  _buildGuideStep('3', 'Copy your key & paste it below:'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // API Key Input
          TextField(
            controller: _apiKeyController,
            obscureText: !_showApiKey,
            decoration: InputDecoration(
              labelText: 'Gemini API Key (Optional)',
              hintText: 'AIzaSy...',
              prefixIcon: const Icon(Icons.key_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_showApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _showApiKey = !_showApiKey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste_rounded),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _apiKeyController.text = data!.text!.trim();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your API key is stored 100% locally on your device.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Complete Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => _completeOnboarding(saveApiKey: true),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Complete Setup & Start 🚀',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => _completeOnboarding(saveApiKey: false),
              child: Text(
                'Skip API key for now (Add later in Settings)',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────── WIDGET HELPERS ───────────────

  Widget _buildMetricSliderTile({
    required ColorScheme cs,
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required VoidCallback onEditTap,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              InkWell(
                onTap: onEditTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        valueText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, size: 14, color: cs.primary),
                    ],
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
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMacroBadge(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildGuideStep(String stepNum, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            stepNum,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
