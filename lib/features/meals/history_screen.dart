import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/meal_log.dart';
import '../stats/stats_controller.dart';
import 'meal_detail_screen.dart';
import 'meals_controller.dart';

/// 식단 기록 히스토리 — 캘린더로 날짜를 고르면 그날의 기록을 봅니다.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selected = DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mealsAsync = ref.watch(mealsForDateProvider(_selected));

    return Scaffold(
      appBar: AppBar(title: const Text('기록 보기')),
      body: Column(
        children: [
          CalendarDatePicker(
            initialDate: _selected,
            firstDate: today.subtract(const Duration(days: 365)),
            lastDate: today,
            onDateChanged: (d) =>
                setState(() => _selected = DateTime(d.year, d.month, d.day)),
          ),
          const Divider(height: 1),
          Expanded(
            child: mealsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (logs) => _DayList(
                date: _selected,
                logs: logs,
                onOpen: (meal) => _openDetail(meal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(MealLog meal) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
    );
    if (changed == true) {
      ref.invalidate(mealsForDateProvider(_selected));
      ref.invalidate(mealsControllerProvider);
      ref.invalidate(statsProvider);
    }
  }
}

class _DayList extends StatelessWidget {
  const _DayList({
    required this.date,
    required this.logs,
    required this.onOpen,
  });
  final DateTime date;
  final List<MealLog> logs;
  final ValueChanged<MealLog> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meals = logs.where((m) => !m.isShake).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${date.year}.${date.month}.${date.day}',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.restaurant_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('식사 ${meals.length}회'),
          ],
        ),
        const SizedBox(height: 12),
        if (meals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('이 날의 식사 기록이 없어요.')),
          )
        else
          for (final m in meals) _MealRow(meal: m, onTap: () => onOpen(m)),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.onTap});
  final MealLog meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${meal.loggedAt.hour.toString().padLeft(2, '0')}:${meal.loggedAt.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Text(meal.slotLabel.characters.first,
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
        ),
        title: Text('${meal.slotLabel} · $time'),
        subtitle: Text(
          (meal.memo ?? '').isNotEmpty ? meal.memo! : '기록 보기',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meal.ai != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _MiniScore(score: meal.ai!.score),
              ),
            if (meal.hasPhoto)
              Icon(Icons.photo_outlined,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            if (meal.ruleViolation == true)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.error),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// AI 점수 미니 배지(히스토리 행용).
class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color c = score >= 80
        ? theme.colorScheme.primary
        : (score >= 50 ? Colors.orange.shade700 : theme.colorScheme.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 11, color: c),
          const SizedBox(width: 3),
          Text('$score',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
