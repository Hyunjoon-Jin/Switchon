import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/program/switchon_program.dart';
import '../../../data/models/daily_log.dart';
import '../meal_calendar.dart';
import '../stats_controller.dart';

/// 1~4주차 식단 달력 카드 — 끼니 달성도를 색으로(초록/노랑/빨강) 보여준다.
class MealCalendarCard extends ConsumerWidget {
  const MealCalendarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final calAsync = ref.watch(mealCalendarProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_month,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('식단 달력', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '끼니(아침·점심·간식·저녁)를 지킨 정도를 색으로 표시해요.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            calAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('달력을 불러오지 못했어요.\n$e',
                  style: theme.textTheme.bodySmall),
              data: (days) => _CalendarGrid(days: days),
            ),
            const SizedBox(height: 12),
            const _Legend(),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.days});
  final List<CalendarDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 헤더: 1~7일차
        Row(
          children: [
            const SizedBox(width: 36),
            for (var d = 1; d <= SwitchOnProgram.daysPerWeek; d++)
              Expanded(
                child: Center(
                  child: Text('$d일',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 1; w <= SwitchOnProgram.totalWeeks; w++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text('$w주',
                      style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600)),
                ),
                for (final day
                    in days.where((e) => e.week == w).toList()
                      ..sort((a, b) => a.day.compareTo(b.day)))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _DayCell(day: day),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});
  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = _colors(theme, day.result);

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showDay(context, day),
          child: Stack(
            children: [
              Center(
                child: Text('${day.day}',
                    style: theme.textTheme.labelMedium?.copyWith(color: fg)),
              ),
              if (day.isFasting)
                Positioned(
                  top: 2,
                  right: 3,
                  child: Text('단',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: fg, fontSize: 8, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static (Color, Color) _colors(ThemeData theme, DayResult r) {
    switch (r) {
      case DayResult.good:
        return (const Color(0xFF2E7D32), Colors.white); // 초록
      case DayResult.ok:
        return (const Color(0xFFF9A825), Colors.black87); // 노랑
      case DayResult.bad:
        return (const Color(0xFFC62828), Colors.white); // 빨강
      case DayResult.none:
        return (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        );
    }
  }
}

void _showDay(BuildContext context, CalendarDay day) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) {
      final theme = Theme.of(context);
      final dateLabel =
          '${day.date.month}월 ${day.date.day}일 · ${day.week}주차 ${day.day}일차';
      const labels = <String, String>{
        'breakfast': '아침',
        'lunch': '점심',
        'snack': '간식',
        'dinner': '저녁',
      };
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(dateLabel, style: theme.textTheme.titleMedium),
                ),
                _ResultChip(result: day.result),
              ],
            ),
            const SizedBox(height: 12),
            for (final slot in DailyLog.mealSlots)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(labels[slot] ?? slot,
                          style: theme.textTheme.labelLarge),
                    ),
                    Expanded(
                      child: Text(day.meals[slot] ?? '-',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.result});
  final DayResult result;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (result) {
      DayResult.good => ('규칙 지킴', const Color(0xFF2E7D32)),
      DayResult.ok => ('보통', const Color(0xFFF9A825)),
      DayResult.bad => ('망한 날', const Color(0xFFC62828)),
      DayResult.none => ('기록 전', Theme.of(context).colorScheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(t,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(const Color(0xFF2E7D32), '규칙 지킴'),
        item(const Color(0xFFF9A825), '보통'),
        item(const Color(0xFFC62828), '망함'),
        item(theme.colorScheme.surfaceContainerHighest, '기록 전'),
      ],
    );
  }
}
