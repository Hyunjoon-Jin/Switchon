import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/program/diet_rules.dart';
import '../../../core/program/food_catalog.dart';
import '../../../core/providers.dart';
import '../../../data/models/meal_log.dart';
import '../meal_editor_screen.dart';
import '../meals_controller.dart';
import 'food_picker.dart';

/// 기록 탭에서 식사 입력 화면으로 넘어가지 않고 바로 식사를 기록하는 바텀 시트.
///
/// 메뉴(검색·양)와 간단 메모만 담아 저장합니다. 사진·AI 분석 등 상세 입력이
/// 필요하면 하단의 '사진·AI 상세 입력'으로 기존 편집 화면을 엽니다.
Future<void> showMealQuickLogSheet(
  BuildContext context, {
  required String slot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MealQuickLogSheet(slot: slot),
  );
}

class _MealQuickLogSheet extends ConsumerStatefulWidget {
  const _MealQuickLogSheet({required this.slot});
  final String slot;

  @override
  ConsumerState<_MealQuickLogSheet> createState() => _MealQuickLogSheetState();
}

class _MealQuickLogSheetState extends ConsumerState<_MealQuickLogSheet> {
  final _memo = TextEditingController();
  final List<FoodPortion> _foods = [];
  bool _saving = false;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  RuleEvaluation? _evaluate() {
    final pos = ref.read(currentStagePositionProvider);
    if (pos == null) return null;
    return DietRules.evaluate(
      stageId: pos.stage.id,
      week: pos.week,
      tagIds: _foods.map((f) => f.encode()).toList(),
    );
  }

  Future<void> _save() async {
    final memo = _memo.text.trim();
    if (_foods.isEmpty && memo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메뉴를 추가하거나 메모를 입력해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    final eval = _evaluate();
    try {
      await ref.read(mealsControllerProvider.notifier).addMeal(
            mealSlot: widget.slot,
            memo: memo,
            loggedAt: DateTime.now(),
            foodTags: _foods.map((f) => f.encode()).toList(),
            ruleViolation: eval?.isViolation,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _openFullEditor() async {
    // 시트를 먼저 닫고 같은 내비게이터로 상세 편집 화면을 연다.
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MealEditorScreen(initialSlot: widget.slot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eval = _evaluate();
    final slotLabel = MealSlot.labelOf(widget.slot);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('$slotLabel 기록', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('메뉴를 검색해 담고 먹은 양을 입력하세요.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),

            FoodPortionEditor(
              foods: _foods,
              onChanged: (v) => setState(() {
                _foods
                  ..clear()
                  ..addAll(v);
              }),
            ),

            if (eval != null && !eval.isClean) ...[
              const SizedBox(height: 12),
              _MiniRuleBanner(eval: eval),
            ],
            const SizedBox(height: 16),

            TextField(
              controller: _memo,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '느낌·양 등 간단히',
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : _openFullEditor,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('사진·AI 상세 입력'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 규칙 위반/주의 안내(간단형).
class _MiniRuleBanner extends StatelessWidget {
  const _MiniRuleBanner({required this.eval});
  final RuleEvaluation eval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isViolation = eval.isViolation;
    final bg = isViolation
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final fg = isViolation
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isViolation ? Icons.info_outline : Icons.lightbulb_outline,
              color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(eval.message ?? '',
                style: TextStyle(color: fg, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
