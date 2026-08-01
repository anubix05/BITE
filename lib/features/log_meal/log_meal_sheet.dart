import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/database/isar_service.dart';
import '../../core/models/meal.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/providers/dashboard_provider.dart';
import 'providers/log_meal_provider.dart';
/// Shows the Gemini-style bottom sheet for logging a meal.
Future<void> showLogMealSheet(BuildContext context, {DateTime? targetDate}) {
  final dateParam = GoRouterState.of(context).uri.queryParameters['date'];
  final activeTargetDate = targetDate ?? (dateParam != null ? DateTime.tryParse(dateParam) : null);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LogMealSheet(targetDate: activeTargetDate),
  );
}
class _LogMealSheet extends ConsumerStatefulWidget {
  const _LogMealSheet({this.targetDate});
  final DateTime? targetDate;
  @override
  ConsumerState<_LogMealSheet> createState() => _LogMealSheetState();
}
class _LogMealSheetState extends ConsumerState<_LogMealSheet> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  List<int>? _imageBytes;
  String? _imagePath;
  List<Meal> _savedMeals = [];
  String? _inlineSnackBarMessage;
  bool _isFromSavedMeal = false;

  void _showInlineSnackBar(String message) {
    setState(() {
      _inlineSnackBarMessage = message;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          if (_inlineSnackBarMessage == message) {
            _inlineSnackBarMessage = null;
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedMeals();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(logMealNotifierProvider.notifier).reset();
      _focusNode.requestFocus();
    });
  }
  Future<void> _loadSavedMeals() async {
    final favs = await isarService.getFavoriteMeals();
    if (mounted) {
      setState(() {
        _savedMeals = favs;
      });
    }
  }
  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imagePath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not access camera/gallery. Check permissions.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
  Future<void> _submit() async {
    HapticFeedback.lightImpact();

    final hasKey = await GeminiService.instance.hasApiKey();
    if (!hasKey) {
      if (mounted) {
        await showApiKeyMissingDialog(context);
      }
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty && _imageBytes == null) {
      if (mounted) {
        _showInlineSnackBar('Please describe what you ate or snap a photo to analyze. 🍛');
      }
      return;
    }

    setState(() {
      _isFromSavedMeal = false;
    });

    await ref.read(logMealNotifierProvider.notifier).analyze(
      text: text.isNotEmpty ? text : null,
      imageBytes: _imageBytes,
    );
  }
  void _retainTextAndEdit() {
    ref.read(logMealNotifierProvider.notifier).reset();
    setState(() {
      _imageBytes = null;
      _imagePath = null;
      if (_isFromSavedMeal) {
        _textController.clear();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logMealNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final sheetHeight = mq.size.height * 0.90;
    final isSuccess = state.status == LogMealStatus.success;

    return PopScope(
      canPop: !isSuccess,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _retainTextAndEdit();
      },
      child: Container(
        height: sheetHeight,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Log Meal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ref.read(logMealNotifierProvider.notifier).reset();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            if (_inlineSnackBarMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Material(
                  elevation: 6,
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant_rounded, size: 20, color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _inlineSnackBarMessage!,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: state.status == LogMealStatus.analyzing
                  ? _AnalyzingView()
                  : state.status == LogMealStatus.success && state.result != null
                      ? _ResultView(
                          result: state.result!,
                          originalInput: _textController.text,
                          imagePath: _imagePath,
                          onConfirm: () async {
                            await ref.read(logMealNotifierProvider.notifier).saveMeal(
                              originalInput: _textController.text,
                              result: state.result!,
                              imagePath: _imagePath,
                              targetDate: widget.targetDate,
                            );
                            ref.invalidate(todaySnapshotProvider);
                            await HapticFeedback.mediumImpact();
                            if (context.mounted) {
                              ref.read(logMealNotifierProvider.notifier).reset();
                              Navigator.of(context).pop();
                            }
                          },
                          onEdit: _retainTextAndEdit,
                          onResultUpdated: (updatedResult) {
                            ref.read(logMealNotifierProvider.notifier).setResult(updatedResult);
                          },
                        )
                      : _InputView(
                          controller: _textController,
                          focusNode: _focusNode,
                          imageBytes: _imageBytes,
                          savedMeals: _savedMeals,
                          targetDate: widget.targetDate,
                          errorMessage: state.status == LogMealStatus.error ? state.errorMessage : null,
                          onSend: _submit,
                          onCamera: () => _pickImage(ImageSource.camera),
                          onGallery: () => _pickImage(ImageSource.gallery),
                          onClearImage: () => setState(() => _imageBytes = null),
                          onSelectSavedMeal: (meal) {
                            setState(() {
                              _isFromSavedMeal = true;
                              _imagePath = meal.imagePath;
                              if (meal.imagePath != null) {
                                try {
                                  _imageBytes = File(meal.imagePath!).readAsBytesSync();
                                } catch (_) {
                                  _imageBytes = null;
                                }
                              } else {
                                _imageBytes = null;
                              }
                            });
                            _textController.text = meal.originalUserInput;
                            final cachedResult = MealAnalysisResult(
                              mealName: meal.aiInterpretation ?? meal.originalUserInput,
                              confidence: 1.0,
                              needsClarification: false,
                              items: meal.items,
                              rawJson: '{"fromMemory": true}',
                            );
                            ref.read(logMealNotifierProvider.notifier).setResult(cachedResult);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
enum LogMode { auto, manual }

class _InputView extends ConsumerStatefulWidget {
  const _InputView({
    required this.controller,
    required this.focusNode,
    required this.imageBytes,
    required this.savedMeals,
    this.targetDate,
    required this.errorMessage,
    required this.onSend,
    required this.onCamera,
    required this.onGallery,
    required this.onClearImage,
    required this.onSelectSavedMeal,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<int>? imageBytes;
  final List<Meal> savedMeals;
  final DateTime? targetDate;
  final String? errorMessage;
  final VoidCallback onSend, onCamera, onGallery, onClearImage;
  final ValueChanged<Meal> onSelectSavedMeal;

  @override
  ConsumerState<_InputView> createState() => _InputViewState();
}

class _InputViewState extends ConsumerState<_InputView> {
  LogMode _logMode = LogMode.auto;

  // Manual Entry Controllers
  final _manualNameCtrl = TextEditingController();
  final _manualCalCtrl = TextEditingController();
  final _manualPCtrl = TextEditingController();
  final _manualCCtrl = TextEditingController();
  final _manualFCtrl = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _saveToMemory = false;

  @override
  void initState() {
    super.initState();
    final now = widget.targetDate ?? DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay.fromDateTime(now);
  }

  @override
  void dispose() {
    _manualNameCtrl.dispose();
    _manualCalCtrl.dispose();
    _manualPCtrl.dispose();
    _manualCCtrl.dispose();
    _manualFCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveManualMeal() async {
    final name = _manualNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meal name.')),
      );
      return;
    }

    await HapticFeedback.mediumImpact();
    final calories = double.tryParse(_manualCalCtrl.text) ?? 0;
    final protein = double.tryParse(_manualPCtrl.text) ?? 0;
    final carbs = double.tryParse(_manualCCtrl.text) ?? 0;
    final fat = double.tryParse(_manualFCtrl.text) ?? 0;

    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final meal = Meal()
      ..date = DateTime(dt.year, dt.month, dt.day)
      ..time = DateFormat('HH:mm').format(dt)
      ..createdAt = dt
      ..updatedAt = dt
      ..mealType = MealType.fromTime(dt)
      ..originalUserInput = name
      ..aiInterpretation = name
      ..isFavorite = _saveToMemory
      ..totalCalories = calories
      ..totalProteinG = protein
      ..totalCarbsG = carbs
      ..totalFatG = fat
      ..items.add(
        MealItem()
          ..name = name
          ..servingDescription = '1 serving'
          ..calories = calories
          ..proteinG = protein
          ..carbsG = carbs
          ..fatG = fat,
      );

    await isarService.saveMeal(meal);
    ref.invalidate(todaySnapshotProvider);
    if (mounted) {
      ref.read(logMealNotifierProvider.notifier).reset();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mode Switcher (Matching History tab segment control) ──
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<LogMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: LogMode.auto,
                  icon: Icon(Icons.auto_awesome_rounded),
                  label: Text('Auto Analyse'),
                ),
                ButtonSegment(
                  value: LogMode.manual,
                  icon: Icon(Icons.edit_note_rounded),
                  label: Text('Manual Entry'),
                ),
              ],
              selected: {_logMode},
              onSelectionChanged: (s) {
                HapticFeedback.lightImpact();
                setState(() => _logMode = s.first);
              },
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: _logMode == LogMode.auto
                  ? _buildAutoAnalyseContent(cs)
                  : _buildManualEntryContent(cs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoAnalyseContent(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What did you eat?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Type naturally — "one plate biryani" or "2 eggs and toast"',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.savedMeals.isNotEmpty) ...[
          Text(
            'Saved Meals (Load from Memory)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              scrollDirection: Axis.horizontal,
              itemCount: widget.savedMeals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final m = widget.savedMeals[i];
                return ChoiceChip(
                  label: Text('❤️ ${m.aiInterpretation ?? m.originalUserInput}'),
                  selected: false,
                  onSelected: (_) => widget.onSelectSavedMeal(m),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.imageBytes != null) ...[
          Stack(
            children: [
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
                            child: Image.memory(
                              Uint8List.fromList(widget.imageBytes!),
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
                  child: Image.memory(
                    Uint8List.fromList(widget.imageBytes!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: widget.onClearImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. "One plate chicken biryani"',
          ),
          onSubmitted: (_) => widget.onSend(),
        ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.errorMessage!,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            _ActionButton(
              icon: Icons.camera_alt_outlined,
              onTap: widget.onCamera,
              tooltip: 'Camera',
              isActive: widget.imageBytes != null,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.photo_library_outlined,
              onTap: widget.onGallery,
              tooltip: 'Gallery',
              isActive: widget.imageBytes != null,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: widget.onSend,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Analyse'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManualEntryContent(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manual Meal Entry',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter meal details, calories, and macros manually',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _manualNameCtrl,
          decoration: InputDecoration(
            labelText: 'Meal Name',
            hintText: 'e.g. Chicken Shawarma',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),

        // ── 2x2 Macro Grid ──
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualCalCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Calories',
                  suffixText: 'kcal',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _manualPCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Protein',
                  suffixText: 'g',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualCCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Carbs',
                  suffixText: 'g',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _manualFCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Fat',
                  suffixText: 'g',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Date & Time Pickers Row ──
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(DateFormat('EEE, MMM d').format(_selectedDate)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (picked != null) {
                    setState(() => _selectedTime = picked);
                  }
                },
                icon: const Icon(Icons.access_time_rounded, size: 18),
                label: Text(_selectedTime.format(context)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Save to Memory Checkbox ──
        CheckboxListTile(
          value: _saveToMemory,
          onChanged: (v) => setState(() => _saveToMemory = v ?? false),
          title: const Text('Save to Memory (Saved Meals)', style: TextStyle(fontSize: 14)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _saveManualMeal,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Save Meal'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isActive = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? cs.primaryContainer : cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
            size: 22,
          ),
        ),
      ),
    );
  }
}
class _AnalyzingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Analysing your meal...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is estimating nutrition',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.originalInput,
    required this.imagePath,
    required this.onConfirm,
    required this.onEdit,
    required this.onResultUpdated,
  });
  final MealAnalysisResult result;
  final String originalInput;
  final String? imagePath;
  final VoidCallback onConfirm, onEdit;
  final ValueChanged<MealAnalysisResult> onResultUpdated;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final confPercent = (result.confidence * 100).toStringAsFixed(0);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _confidenceColor(result.confidence).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: _confidenceColor(result.confidence)),
                const SizedBox(width: 4),
                Text(
                  '$confPercent% confidence',
                  style: TextStyle(
                    color: _confidenceColor(result.confidence),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onEdit,
                tooltip: 'Back to input',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.mealName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (originalInput.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"$originalInput"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroStat(
                  label: 'Calories',
                  value: result.totalCalories.toStringAsFixed(0),
                  unit: 'kcal',
                  color: cs.primary,
                ),
                _MacroStat(
                  label: 'Protein',
                  value: result.totalProtein.toStringAsFixed(0),
                  unit: 'g',
                  color: AppTheme.proteinColor,
                ),
                _MacroStat(
                  label: 'Carbs',
                  value: result.totalCarbs.toStringAsFixed(0),
                  unit: 'g',
                  color: AppTheme.carbsColor,
                ),
                _MacroStat(
                  label: 'Fat',
                  value: result.totalFat.toStringAsFixed(0),
                  unit: 'g',
                  color: AppTheme.fatColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Items (${result.items.length}) — Tap item to edit numbers',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          ...result.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return _ItemRow(
              item: item,
              onEdit: () => _editItemDialog(context, idx, item),
            );
          }),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded),
                  SizedBox(width: 8),
                  Text('Confirm & Save'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Edit / Try Again'),
            ),
          ),
        ],
      ),
    );
  }
  void _editItemDialog(BuildContext context, int index, MealItem item) async {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(text: item.name);
    final portionCtrl = TextEditingController(text: item.servingDescription);
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
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portionCtrl,
                decoration: InputDecoration(
                  labelText: 'Serving Portion',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    if (saved == true) {
      final updatedItems = List<MealItem>.from(result.items);
      final newItem = MealItem()
        ..name = nameCtrl.text.trim()
        ..servingDescription = portionCtrl.text.trim()
        ..calories = double.tryParse(calCtrl.text) ?? item.calories
        ..proteinG = double.tryParse(pCtrl.text) ?? item.proteinG
        ..carbsG = double.tryParse(cCtrl.text) ?? item.carbsG
        ..fatG = double.tryParse(fCtrl.text) ?? item.fatG
        ..estimatedWeightG = item.estimatedWeightG;
      updatedItems[index] = newItem;
      final updatedResult = MealAnalysisResult(
        mealName: result.mealName,
        confidence: result.confidence,
        needsClarification: result.needsClarification,
        items: updatedItems,
        rawJson: result.rawJson,
      );
      onResultUpdated(updatedResult);
    }
  }
  Color _confidenceColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF34D399);
    if (confidence >= 0.6) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }
}
class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final String label, value, unit;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(unit, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onEdit});
  final MealItem item;
  final VoidCallback onEdit;
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
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.servingDescription} • ${item.estimatedWeightG.toStringAsFixed(0)}g',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.calories.toStringAsFixed(0)} kcal',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}