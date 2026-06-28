import 'package:flutter/material.dart';

import '../../../data/models/meal_log.dart';

/// AI 분석 결과 카드(점수·판정·피드백·조절제안·영양 추정). 상세/편집 공용.
class AiResultCard extends StatelessWidget {
  const AiResultCard({super.key, required this.analysis, this.headerAction});

  final AiAnalysis analysis;

  /// 헤더 오른쪽에 둘 위젯(예: "다시 분석" 버튼). 없으면 생략.
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = analysis;

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
                if (headerAction != null) headerAction!,
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ScoreCircle(score: a.score, accent: accent),
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

            // 영양 추정
            if (a.hasNutrition) ...[
              const SizedBox(height: 14),
              _NutritionRow(a: a),
              if (a.confidenceLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('· ${a.confidenceLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],

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
                              color: theme.colorScheme.onSecondaryContainer)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('※ AI 분석은 참고용이며, 칼로리·영양은 사진/메뉴 기반 추정치입니다. '
                '의학적 진단이 아닙니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.score, required this.accent});
  final int score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
          Text('$score',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: accent, height: 1.0)),
          Text('점', style: theme.textTheme.labelSmall?.copyWith(color: accent)),
        ],
      ),
    );
  }
}

/// 칼로리 + 탄·단·지 가로 표시.
class _NutritionRow extends StatelessWidget {
  const _NutritionRow({required this.a});
  final AiAnalysis a;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(String, String)>[
      ('칼로리', '${a.calories ?? 0} kcal'),
      ('탄수화물', '${a.carbsG ?? 0} g'),
      ('단백질', '${a.proteinG ?? 0} g'),
      ('지방', '${a.fatG ?? 0} g'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final it in items)
            Column(
              children: [
                Text(it.$2,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(it.$1,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }
}
