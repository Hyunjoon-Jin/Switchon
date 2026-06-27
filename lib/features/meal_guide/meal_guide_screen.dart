import 'package:flutter/material.dart';

import '../../core/program/switchon_program.dart';

/// 식단 가이드 — 전체 4주 가이드라인을 참고할 수 있게 제시.
/// 현재 단계는 강조해서 펼쳐 보여주고, 다른 주차도 열어볼 수 있어요.
class MealGuideScreen extends StatelessWidget {
  const MealGuideScreen({super.key, this.currentStageId});

  /// 현재 단계 id(강조용). 없으면 첫 단계를 펼침.
  final String? currentStageId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = currentStageId ?? SwitchOnProgram.stages.first.id;

    return Scaffold(
      appBar: AppBar(title: const Text('식단 가이드')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _LifeRulesCard(),
          const SizedBox(height: 16),
          Text('주차별 식단 가이드',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final stage in SwitchOnProgram.stages)
            _StageTile(stage: stage, isCurrent: stage.id == current),
          const SizedBox(height: 16),
          Text(
            '※ 박용우 「스위치온 다이어트」 공개 정보를 요약한 가이드예요. '
            '판본에 따라 차이가 있을 수 있고, 의학적 조언이 아닙니다. '
            '정확한 식단과 본인 건강 상태는 공식 책·전문가 상담을 따르세요.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 어느 단계에서나 지키는 핵심 생활 규칙.
class _LifeRulesCard extends StatelessWidget {
  const _LifeRulesCard();

  static const _rules = [
    (Icons.water_drop_outlined, '물 2L 이상'),
    (Icons.bedtime_outlined, '수면 6시간 이상'),
    (Icons.nightlight_outlined, '취침 4시간 전 식사 마감'),
    (Icons.fitness_center_outlined, '주 4회 이상 고강도 운동'),
    (Icons.timer_outlined, '2주차부터 주 1회 24시간 단식'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('매일 지키는 핵심 규칙',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer)),
            const SizedBox(height: 12),
            for (final r in _rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(r.$1,
                        size: 20,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.$2,
                          style: TextStyle(
                              color:
                                  theme.colorScheme.onSecondaryContainer)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 한 단계의 식단 가이드 (펼침형).
class _StageTile extends StatelessWidget {
  const _StageTile({required this.stage, required this.isCurrent});
  final StageRule stage;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mp = stage.mealPlan;
    final meals = <(IconData, String, String?)>[
      (Icons.local_drink_outlined, '셰이크', mp.shake),
      (Icons.lunch_dining_outlined, '점심', mp.lunch),
      (Icons.dinner_dining_outlined, '저녁', mp.dinner),
      (Icons.cookie_outlined, '간식', mp.snack),
      (Icons.apple, '과일', mp.fruit),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: ExpansionTile(
        initiallyExpanded: isCurrent,
        title: Row(
          children: [
            Expanded(
              child: Text(stage.title, style: theme.textTheme.titleSmall),
            ),
            if (isCurrent)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('현재',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onPrimary)),
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // 끼니별
          for (final m in meals)
            if (m.$3 != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(m.$1, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    SizedBox(
                        width: 40,
                        child:
                            Text(m.$2, style: theme.textTheme.labelMedium)),
                    Expanded(child: Text(m.$3!)),
                  ],
                ),
              ),
          const Divider(height: 20),
          _chips(context, '허용', stage.allowedFoods,
              theme.colorScheme.primary),
          const SizedBox(height: 10),
          _chips(context, '주의·제한', stage.forbiddenFoods,
              theme.colorScheme.error),
          if (stage.exampleMeals.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('예시 식단', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final e in stage.exampleMeals)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.restaurant_menu, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chips(
      BuildContext context, String label, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in items)
              Chip(
                label: Text(i),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: color.withOpacity(0.4)),
              ),
          ],
        ),
      ],
    );
  }
}
