import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/meal.dart';
import '../dashboard/providers/dashboard_provider.dart';
import 'providers/log_meal_provider.dart';

class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key});

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  List<int>? _imageBytes;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imagePath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not access camera/photo gallery. Please check permissions.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please describe what you ate or snap a photo to analyze. 🍛'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logMealNotifierProvider);
    final isSuccess = state.status == LogMealStatus.success;

    return PopScope(
      canPop: !isSuccess,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _retainTextAndEdit();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(logMealNotifierProvider.notifier).reset();
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
                    'Log Meal',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            Expanded(
              child: state.status == LogMealStatus.analyzing
                  ? _AnalyzingView()
                  : state.status == LogMealStatus.success &&
                          state.result != null
                      ? _ResultView(
                          result: state.result!,
                          originalInput: _textController.text,
                          imagePath: _imagePath,
                          onConfirm: () async {
                            final dateParam = GoRouterState.of(context).uri.queryParameters['date'];
                            final targetDate = dateParam != null ? DateTime.tryParse(dateParam) : null;
                            await ref
                                .read(logMealNotifierProvider.notifier)
                                .saveMeal(
                                  originalInput: _textController.text,
                                  result: state.result!,
                                  imagePath: _imagePath,
                                  targetDate: targetDate,
                                );
                            ref.invalidate(todaySnapshotProvider);
                            await HapticFeedback.mediumImpact();
                            if (context.mounted) {
                              ref
                                  .read(logMealNotifierProvider.notifier)
                                  .reset();
                              context.pop();
                            }
                          },
                          onEdit: _retainTextAndEdit,
                        )
                      : _InputView(
                          controller: _textController,
                          focusNode: _focusNode,
                          imageBytes: _imageBytes,
                          errorMessage: state.status == LogMealStatus.error
                              ? state.errorMessage
                              : null,
                          onSend: _submit,
                          onCamera: () => _pickImage(ImageSource.camera),
                          onGallery: () => _pickImage(ImageSource.gallery),
                          onClearImage: () =>
                              setState(() => _imageBytes = null),
                        ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ─────────────────────────────────────────────────────────────────
// Input View
// ─────────────────────────────────────────────────────────────────
class _InputView extends StatelessWidget {
  const _InputView({
    required this.controller,
    required this.focusNode,
    required this.imageBytes,
    required this.errorMessage,
    required this.onSend,
    required this.onCamera,
    required this.onGallery,
    required this.onClearImage,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<int>? imageBytes;
  final String? errorMessage;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'What did you eat?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type naturally — "one plate biryani" or "2 eggs and toast"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
          ),

          const SizedBox(height: 24),

          // Image preview
          if (imageBytes != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    Uint8List.fromList(imageBytes!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onClearImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Text field
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. "One plate chicken biryani"',
            ),
            onSubmitted: (_) => onSend(),
          ),

          if (errorMessage != null) ...[
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
                      errorMessage!,
                      style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Action row
          Row(
            children: [
              _ActionButton(
                icon: Icons.camera_alt_outlined,
                onTap: onCamera,
                tooltip: 'Camera',
                isActive: imageBytes != null,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.photo_library_outlined,
                onTap: onGallery,
                tooltip: 'Gallery',
                isActive: imageBytes != null,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Analyse'),
              ),
            ],
          ),
        ],
      ),
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
            color: isActive
                ? cs.primaryContainer
                : cs.onSurface.withValues(alpha: 0.06),
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

// ─────────────────────────────────────────────────────────────────
// Analyzing View
// ─────────────────────────────────────────────────────────────────
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is estimating nutrition',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Result View
// ─────────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.originalInput,
    required this.imagePath,
    required this.onConfirm,
    required this.onEdit,
  });

  final MealAnalysisResult result;
  final String originalInput;
  final String? imagePath;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _confidenceColor(result.confidence).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: _confidenceColor(result.confidence),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(result.confidence * 100).round()}% confidence',
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            '"$originalInput"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
          ),

          const SizedBox(height: 24),

          // Macro summary card
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
                    color: cs.primary),
                _MacroStat(
                    label: 'Protein',
                    value: result.totalProtein.toStringAsFixed(0),
                    unit: 'g',
                    color: AppTheme.proteinColor),
                _MacroStat(
                    label: 'Carbs',
                    value: result.totalCarbs.toStringAsFixed(0),
                    unit: 'g',
                    color: AppTheme.carbsColor),
                _MacroStat(
                    label: 'Fat',
                    value: result.totalFat.toStringAsFixed(0),
                    unit: 'g',
                    color: AppTheme.fatColor),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Items list
          Text(
            'Items (${result.items.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 12),
          ...result.items.map(
            (item) => _ItemRow(item: item),
          ),

          const SizedBox(height: 32),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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

          // Edit / redo
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Edit / Try Again'),
          ),
        ],
      ),
    );
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

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          unit,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final MealItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
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
                Text(
                  '${item.servingDescription} • ${item.estimatedWeightG.toStringAsFixed(0)}g',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
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
    );
  }
}
