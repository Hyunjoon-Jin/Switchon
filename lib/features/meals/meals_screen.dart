import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/meal_log.dart';
import '../home/daily_log_controller.dart';
import '../meal_guide/meal_guide_screen.dart';
import 'history_screen.dart';
import 'meal_detail_screen.dart';
import 'meal_editor_screen.dart';
import 'meals_controller.dart';

/// 오늘의 식단 기록 — 셰이크 카운터 + 끼니별 식사 + 상세/히스토리.
class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 기록'),
        actions: [
          IconButton(
            tooltip: '기록 보기',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            tooltip: '식단 가이드',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MealGuideScreen(
                  currentStageId:
                      ref.read(currentStagePositionProvider)?.stage.id,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MealEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('식사 기록'),
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (logs) {
          final shakes = shakeCountOf(logs);
          final meals = logs.where((m) => !m.isShake).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ShakeCounter(
                count: shakes,
                onAdd: () =>
                    ref.read(mealsControllerProvider.notifier).addShake(),
              ),
              const SizedBox(height: 12),
              const _WaterCard(),
              const SizedBox(height: 20),
              Text('식사 (${meals.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (meals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('아직 기록한 식사가 없어요.')),
                )
              else
                for (final m in meals)
                  _MealRow(
                    meal: m,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MealDetailScreen(meal: m),
                      ),
                    ),
                  ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _ShakeCounter extends StatelessWidget {
  const _ShakeCounter({required this.count, required this.onAdd});
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.local_drink_outlined,
                size: 36, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('단백질 셰이크', style: theme.textTheme.titleMedium),
                  Text('오늘 $count회',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('1회'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 물 빠른 기록 카드 — 홈 체크리스트의 물과 같은 데이터(자동 동기화).
class _WaterCard extends ConsumerWidget {
  const _WaterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logAsync = ref.watch(dailyLogControllerProvider);
    final log = logAsync.valueOrNull ?? DailyLog.empty(DateTime.now());
    final ratio =
        (log.waterMl / DailyLog.waterTargetMl).clamp(0.0, 1.0).toDouble();

    Future<void> add(int ml) async {
      try {
        await ref.read(dailyLogControllerProvider.notifier).addWater(ml);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요.')),
          );
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  log.waterDone
                      ? Icons.water_drop
                      : Icons.water_drop_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('물', style: theme.textTheme.titleMedium),
                      Text('${log.waterMl} / ${DailyLog.waterTargetMl}ml',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (log.waterDone)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: ratio, minHeight: 6),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => add(250),
                  child: const Text('+250ml'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => add(500),
                  child: const Text('+500ml'),
                ),
                const Spacer(),
                if (log.waterMl > 0)
                  TextButton(
                    onPressed: () => add(-log.waterMl),
                    child: const Text('초기화'),
                  ),
              ],
            ),
          ],
        ),
      ),
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
