import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/food_catalog.dart';
import '../../core/program/switchon_program.dart';
import '../../core/providers.dart';
import '../../data/models/community.dart';
import '../../data/models/meal_log.dart';
import '../community/community_controller.dart';
import '../community/nickname.dart';
import '../stats/stats_controller.dart';
import 'meal_editor_screen.dart';
import 'meals_controller.dart';
import 'widgets/ai_result_card.dart';

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
  bool _violationOverridden = false;
  bool _sharing = false;

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
      final detail = e is StateError ? e.message : e.toString();
      _snack('AI 분석 실패: $detail');
    }
  }

  /// 식단을 커뮤니티 피드에 실시간 공유.
  Future<void> _shareMeal(BuildContext context, WidgetRef ref) async {
    final name = await ensureNickname(context, ref);
    if (name == null || !context.mounted) return;

    // 한마디 캡션 입력 다이얼로그
    final captionCtrl = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('식단 공유'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('같은 주차 동료들에게 오늘 식단을 공유해요!'),
            const SizedBox(height: 12),
            TextField(
              controller: captionCtrl,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '한마디 (선택)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
              child: const Text('공유')),
        ],
      ),
    );
    captionCtrl.dispose();
    if (caption == null || !mounted) return;

    setState(() => _sharing = true);
    try {
      final pos = ref.read(currentStagePositionProvider);
      final week = pos?.week ?? 1;
      final communityService = ref.read(communityServiceProvider);

      // 식단 사진이 있으면 공개 버킷에 복사(signed URL 대신 public URL 사용)
      String? publicPhotoUrl;
      if (meal.hasPhoto) {
        try {
          final Uint8List bytes = await ref
              .read(supabaseClientProvider)
              .storage
              .from('meal-photos')
              .download(meal.photos.first);
          final fileName = 'meal_share_${DateTime.now().millisecondsSinceEpoch}.jpg';
          publicPhotoUrl = await communityService.uploadPhoto(bytes, fileName);
        } catch (_) {
          // 사진 공유 실패해도 나머지 정보는 공유
        }
      }

      final ai = _ai;
      final mealData = MealShareData(
        slot: meal.mealSlot ?? 'meal',
        slotLabel: meal.slotLabel,
        foodTags: meal.foodTags
            .map((raw) => FoodPortion.decode(raw).display)
            .toList(),
        aiVerdict: ai?.verdict,
        aiScore: ai?.score,
        aiCalories: ai?.calories,
        aiCarbsG: ai?.carbsG,
        aiProteinG: ai?.proteinG,
        aiFatG: ai?.fatG,
        aiFoods: ai?.foods,
        memo: meal.memo,
        photoUrl: publicPhotoUrl,
      );

      await communityService.createMealSharePost(
        week: week,
        authorName: name,
        mealData: mealData,
        content: caption,
      );

      // 피드 갱신 (내 게시글은 Realtime 으로도 오지만 즉시 반영)
      ref.invalidate(feedProvider);

      if (mounted) _snack('커뮤니티에 공유했어요!');
    } catch (e) {
      if (mounted) _snack('공유 실패: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
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
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_outlined),
            tooltip: '커뮤니티에 공유',
            onPressed: _sharing ? null : () => _shareMeal(context, ref),
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
            Text('먹은 메뉴', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final raw in meal.foodTags)
                  Chip(
                    label: Text(FoodPortion.decode(raw).display),
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

    return AiResultCard(
      analysis: analysis!,
      headerAction: analyzing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(onPressed: onAnalyze, child: const Text('다시 분석')),
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
