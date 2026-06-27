import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/diet_rules.dart';
import '../../core/program/switchon_program.dart';
import '../../core/providers.dart';
import '../../data/models/meal_log.dart';
import '../stats/stats_controller.dart';
import 'meal_editor_screen.dart';
import 'meals_controller.dart';

/// 식단 기록 상세 보기. 수정/삭제 + AI 식단 판독. 변경 시 pop(true).
class MealDetailScreen extends ConsumerStatefulWidget {
  const MealDetailScreen({super.key, required this.meal});
  final MealLog meal;

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  AiAnalysis? _ai;
  bool _analyzing = false;
  bool _violationOverridden = false; // AI가 rule_violation 을 덮어썼는지

  MealLog get meal => widget.meal;

  @override
  void initState() {
    super.initState();
    _ai = meal.ai;
  }

  Future<void> _analyze() async {
    if (!meal.hasPhoto) {
      _snack('사진을 먼저 추가해 주세요. (수정 → 사진 추가)');
      return;
    }
    setState(() => _analyzing = true);
    try {
      final pos = ref.read(currentStagePositionProvider);
      final stage = pos?.stage ?? SwitchOnProgram.stages.first;
      final week = pos?.week ?? 1;
      final day = pos?.day ?? 1;
      final plan = stage.mealPlan;
      final planText = [
        '셰이크: ${plan.shake}',
        if (plan.lunch != null) '점심: ${plan.lunch}',
        if (plan.dinner != null) '저녁: ${plan.dinner}',
        if (plan.snack != null) '간식: ${plan.snack}',
        if (plan.fruit != null) '과일: ${plan.fruit}',
      ].join(' / ');

      final result = await ref.read(supabaseServiceProvider).analyzeMeal(
            mealId: meal.id,
            week: week,
            day: day,
            stageTitle: stage.title,
            allowedFoods: stage.allowedFoods,
            forbiddenFoods: stage.forbiddenFoods,
            mealPlan: planText,
          );

      // 목록·통계 갱신 (②B: violation 이면 규칙 위반 배지/통계가 바뀜)
      ref.invalidate(mealsControllerProvider);
      ref.invalidate(mealsForDateProvider);
      ref.invalidate(statsProvider);

      if (!mounted) return;
      setState(() {
        _ai = result;
        _violationOverridden = result.isViolation;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      _snack('AI 분석에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${meal.loggedAt.hour.toString().padLeft(2, '0')}:${meal.loggedAt.minute.toString().padLeft(2, '0')}';
    // AI 가 위반으로 판정했으면 즉시 배지에 반영.
    final showViolation = _violationOverridden || meal.ruleViolation == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(meal.slotLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '수정',
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => MealEditorScreen(existing: meal),
                ),
              );
              if (changed == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Chip(
                label: Text(meal.slotLabel),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Text(time, style: theme.textTheme.bodyMedium),
              const Spacer(),
              if (showViolation)
                Chip(
                  label: const Text('단계 제한'),
                  backgroundColor: theme.colorScheme.errorContainer,
                  labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (meal.photos.isNotEmpty) ...[
            SizedBox(
              height: 280,
              child: PageView(
                children: [
                  for (final p in meal.photos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _SignedImage(path: p),
                    ),
                ],
              ),
            ),
            if (meal.photos.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('사진 ${meal.photos.length}장 · 좌우로 넘겨보세요',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 16),
          ],

          // --- AI 식단 판독 ---
          _AiSection(
            analysis: _ai,
            analyzing: _analyzing,
            hasPhoto: meal.hasPhoto,
            onAnalyze: _analyze,
          ),
          const SizedBox(height: 16),

          if (meal.foodTags.isNotEmpty) ...[
            Text('음식 태그', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in meal.foodTags)
                  Chip(
                    label: Text(FoodTags.byId(id)?.label ?? id),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if ((meal.memo ?? '').isNotEmpty) ...[
            Text('메모', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(meal.memo!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(mealsControllerProvider.notifier).delete(meal.id);
    if (context.mounted) Navigator.pop(context, true);
  }
}

/// AI 분석 섹션 — 미분석이면 버튼, 분석 결과가 있으면 결과 카드.
class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.analysis,
    required this.analyzing,
    required this.hasPhoto,
    required this.onAnalyze,
  });

  final AiAnalysis? analysis;
  final bool analyzing;
  final bool hasPhoto;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (analysis == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: analyzing || !hasPhoto ? null : onAnalyze,
            icon: analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(analyzing ? 'AI가 분석 중…' : 'AI 식단 분석'),
          ),
          if (!hasPhoto)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('사진이 있어야 분석할 수 있어요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
        ],
      );
    }

    final a = analysis!;
    final Color accent;
    final IconData icon;
    if (a.isFit) {
      accent = theme.colorScheme.primary;
      icon = Icons.check_circle_outline;
    } else if (a.isViolation) {
      accent = theme.colorScheme.error;
      icon = Icons.error_outline;
    } else {
      accent = Colors.orange.shade700;
      icon = Icons.warning_amber_outlined;
    }

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: accent),
                const SizedBox(width: 6),
                Text('AI 식단 분석', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (analyzing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: onAnalyze,
                    child: const Text('다시 분석'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 점수 원형
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.12),
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${a.score}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: accent, height: 1.0)),
                      Text('점',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: accent)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 18, color: accent),
                          const SizedBox(width: 4),
                          Text(a.verdictLabel,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: accent)),
                        ],
                      ),
                      if (a.foods.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(a.foods,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (a.feedback.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(a.feedback, style: theme.textTheme.bodyMedium),
            ],
            if (a.suggestion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.suggestion,
                          style: TextStyle(
                              color:
                                  theme.colorScheme.onSecondaryContainer)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('※ AI 분석은 참고용이며 의학적 진단이 아닙니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SignedImage extends ConsumerWidget {
  const _SignedImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(supabaseServiceProvider).signedPhotoUrl(path),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.network(snap.data!,
              fit: BoxFit.cover, width: double.infinity);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
