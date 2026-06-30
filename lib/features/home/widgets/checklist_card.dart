import 'package:flutter/material.dart';

import '../../../core/program/switchon_program.dart';
import '../../../data/models/daily_log.dart';

/// 일일 체크리스트 카드 — 끼니(아침·점심·간식·저녁) + 고강도 운동.
/// 끼니는 식단표(주차·일차)대로 안내가 채워지고, 동그라미를 눌러 체크합니다.
class ChecklistCard extends StatelessWidget {
  const ChecklistCard({
    super.key,
    required this.log,
    required this.dayMeals,
    required this.onToggleMeal,
    required this.onToggleExercise,
  });

  final DailyLog log;
  final DayMeals dayMeals;
  final ValueChanged<String> onToggleMeal; // 슬롯 키
  final VoidCallback onToggleExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (log.completionRate * 100).round();

    const slots = <(String, String)>[
      ('breakfast', '아침'),
      ('lunch', '점심'),
      ('snack', '간식'),
      ('dinner', '저녁'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('오늘의 체크리스트',
                      style: theme.textTheme.titleMedium),
                ),
                _CompletionRing(rate: log.completionRate, percent: percent),
              ],
            ),
            const SizedBox(height: 12),

            // 끼니 — 식단표대로 채워진 안내 + 동그라미 체크.
            for (final s in slots)
              _MealRow(
                label: s.$2,
                plan: dayMeals.forSlot(s.$1),
                done: log.mealDone(s.$1),
                onTap: () => onToggleMeal(s.$1),
              ),

            const Divider(height: 28),

            // 고강도 운동
            _ToggleRow(
              icon: Icons.fitness_center_outlined,
              label: '고강도 운동',
              done: log.exerciseDone,
              onTap: onToggleExercise,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.rate, required this.percent});
  final double rate;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: rate,
              strokeWidth: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text('$percent%', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// 끼니 한 줄 — 동그라미 체크 + 끼니명 + 식단표 안내(셰이크/저탄수화물식 등).
class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.label,
    required this.plan,
    required this.done,
    required this.onTap,
  });

  final String label;
  final String plan;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFast = plan == SwitchOnProgram.mFast;
    final color = done ? theme.colorScheme.primary : theme.colorScheme.outline;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 24,
              color: color,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 36,
              child: Text(label, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                plan,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isFast
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isFast ? FontWeight.w600 : null,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
