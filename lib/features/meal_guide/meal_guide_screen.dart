import 'package:flutter/material.dart';

import '../../core/program/switchon_program.dart';

/// 현재 단계의 식단 가이드 — 끼니별 식단 + 허용/금지 + 예시 식단.
class MealGuideScreen extends StatelessWidget {
  const MealGuideScreen({super.key, required this.stage});
  final StageRule stage;

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

    return Scaffold(
      appBar: AppBar(title: const Text('식단 가이드')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(stage.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),

          // 끼니별 식단
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('끼니별 가이드', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final m in meals)
                    if (m.$3 != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(m.$1,
                                size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 44,
                              child: Text(m.$2,
                                  style: theme.textTheme.labelLarge),
                            ),
                            const SizedBox(width: 4),
                            Expanded(child: Text(m.$3!)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _FoodChips(
            title: '허용 식품',
            items: stage.allowedFoods,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _FoodChips(
            title: '주의·제한 식품',
            items: stage.forbiddenFoods,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),

          if (stage.exampleMeals.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('예시 식단', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (final e in stage.exampleMeals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.restaurant_menu, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
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

class _FoodChips extends StatelessWidget {
  const _FoodChips({
    required this.title,
    required this.items,
    required this.color,
  });
  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleMedium?.copyWith(color: color)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in items)
                  Chip(
                    label: Text(i),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: color.withOpacity(0.4)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
