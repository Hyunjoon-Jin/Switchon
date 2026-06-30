import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/switchon_program.dart';
import '../../core/providers.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/meal_log.dart';
import '../home/daily_log_controller.dart';
import '../meal_guide/meal_guide_screen.dart';
import 'history_screen.dart';
import 'meal_detail_screen.dart';
import 'meal_editor_screen.dart';
import 'meals_controller.dart';

/// 끼니 슬롯 순서/라벨 (식단표와 동일: 아침·점심·간식·저녁).
const List<(String, String)> kMealSlots = [
  ('breakfast', '아침'),
  ('lunch', '점심'),
  ('snack', '간식'),
  ('dinner', '저녁'),
];

/// 오늘의 기록 — 끼니별(아침·점심·간식·저녁) 식단표 안내 + 먹은 음식 기록.
/// 오늘 탭의 체크리스트와 같은 데이터(체크 상태)를 공유합니다.
class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsControllerProvider);
    final logAsync = ref.watch(dailyLogControllerProvider);
    final pos = ref.watch(currentStagePositionProvider);
    final dayMeals = SwitchOnProgram.dayMeals(pos?.week ?? 1, pos?.day ?? 1);

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
                  currentStageId: pos?.stage.id,
                ),
              ),
            ),
          ),
        ],
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (logs) {
          final log = logAsync.valueOrNull ?? DailyLog.empty(DateTime.now());
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final s in kMealSlots) ...[
                _MealSlotCard(
                  label: s.$2,
                  plan: dayMeals.forSlot(s.$1),
                  done: log.mealDone(s.$1),
                  meals:
                      logs.where((m) => m.mealSlot == s.$1).toList(),
                  onToggle: () => _toggle(context, ref, s.$1),
                  onAdd: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MealEditorScreen(initialSlot: s.$1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, String slot) async {
    try {
      await ref.read(dailyLogControllerProvider.notifier).toggleMeal(slot);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }
}

/// 끼니 한 칸 — 체크(동그라미) + 식단표 안내 + 먹은 음식 목록 + 식사기록 추가.
class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.label,
    required this.plan,
    required this.done,
    required this.meals,
    required this.onToggle,
    required this.onAdd,
  });

  final String label;
  final String plan;
  final bool done;
  final List<MealLog> meals;
  final VoidCallback onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFast = plan == SwitchOnProgram.mFast;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: done ? '체크 해제' : '챙김 체크',
                  onPressed: onToggle,
                  icon: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isFast
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isFast ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),

            // 먹은 음식 목록(있으면).
            if (meals.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final m in meals)
                _LoggedMeal(
                  meal: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MealDetailScreen(meal: m),
                    ),
                  ),
                ),
            ],

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('식사기록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 끼니에 기록된 음식 한 줄.
class _LoggedMeal extends StatelessWidget {
  const _LoggedMeal({required this.meal, required this.onTap});
  final MealLog meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${meal.loggedAt.hour.toString().padLeft(2, '0')}:${meal.loggedAt.minute.toString().padLeft(2, '0')}';
    final title = (meal.memo ?? '').isNotEmpty ? meal.memo! : '기록 보기';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.fiber_manual_record,
                size: 8, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (meal.hasPhoto)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.photo_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
            if (meal.ruleViolation == true)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.error),
              ),
            const SizedBox(width: 4),
            Text(time,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
