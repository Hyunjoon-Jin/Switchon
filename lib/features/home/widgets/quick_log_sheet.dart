import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/daily_log.dart';
import '../../fasting/fasting_controller.dart';
import '../../meals/meals_controller.dart';
import '../daily_log_controller.dart';

/// 어떤 탭에서든 '+ 기록' FAB으로 열리는 빠른 기록 바텀 시트.
Future<void> showQuickLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _QuickLogSheet(),
  );
}

class _QuickLogSheet extends ConsumerWidget {
  const _QuickLogSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final log = ref.watch(dailyLogControllerProvider).valueOrNull ??
        DailyLog.empty(DateTime.now());
    final meals = ref.watch(mealsControllerProvider).valueOrNull ?? [];
    final shakes = shakeCountOf(meals);
    final session = ref.watch(fastingControllerProvider).valueOrNull;

    Future<void> guard(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했어요. 잠시 후 다시 시도해 주세요.')),
          );
        }
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('빠른 기록', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),

          // 물
          _SheetRow(
            icon: log.waterDone ? Icons.water_drop : Icons.water_drop_outlined,
            title: '물',
            subtitle: '${log.waterMl} / ${DailyLog.waterTargetMl}ml',
            done: log.waterDone,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SmallBtn(
                  label: '+250',
                  onTap: () => guard(() =>
                      ref.read(dailyLogControllerProvider.notifier).addWater(250)),
                ),
                const SizedBox(width: 6),
                _SmallBtn(
                  label: '+500',
                  onTap: () => guard(() =>
                      ref.read(dailyLogControllerProvider.notifier).addWater(500)),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // 셰이크
          _SheetRow(
            icon: Icons.local_drink_outlined,
            title: '단백질 셰이크',
            subtitle: shakes == 0 ? '기록 없음' : '오늘 $shakes회',
            done: shakes > 0,
            trailing: _SmallBtn(
              label: '+1회',
              onTap: () =>
                  guard(() => ref.read(mealsControllerProvider.notifier).addShake()),
            ),
          ),
          const Divider(height: 20),

          // 단식
          _FastingSheetRow(
            session: session,
            fastingDone: log.fastingDone,
            onStart: (h) => guard(() async {
              await ref.read(fastingControllerProvider.notifier).start(h);
              if (!log.fastingDone) {
                await ref
                    .read(dailyLogControllerProvider.notifier)
                    .toggleFasting();
              }
            }),
            onStop: () => guard(() async {
              final s = ref.read(fastingControllerProvider).valueOrNull;
              if (s == null) return;
              final done = s.reachedGoalAt(DateTime.now());
              await ref
                  .read(fastingControllerProvider.notifier)
                  .stop(canceled: !done);
            }),
          ),
          const Divider(height: 20),

          // 수면
          _SheetRow(
            icon: log.sleepDone ? Icons.bedtime : Icons.bedtime_outlined,
            title: '수면',
            subtitle: log.sleepHours != null
                ? '${log.sleepHours!.toStringAsFixed(1)}h'
                : '기록 없음',
            done: log.sleepDone,
            trailing: TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 홈 탭으로 유도 (수면은 타임피커가 필요해 시트 내 처리 생략)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('수면은 홈 탭 체크리스트에서 시각을 선택해 기록하세요.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('기록하기'),
            ),
          ),
          const Divider(height: 20),

          // 운동
          _SheetRow(
            icon: Icons.fitness_center_outlined,
            title: '고강도 운동',
            subtitle: log.exerciseDone ? '완료' : '미완료',
            done: log.exerciseDone,
            trailing: _SmallBtn(
              label: log.exerciseDone ? '취소' : '완료',
              onTap: () => guard(() =>
                  ref.read(dailyLogControllerProvider.notifier).toggleExercise()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium),
              Text(subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _FastingSheetRow extends StatelessWidget {
  const _FastingSheetRow({
    required this.session,
    required this.fastingDone,
    required this.onStart,
    required this.onStop,
  });
  final dynamic session;
  final bool fastingDone;
  final ValueChanged<int> onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (session != null) {
      final elapsed = session.elapsedAt(DateTime.now());
      final h = elapsed.inHours.toString().padLeft(2, '0');
      final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
      return _SheetRow(
        icon: Icons.timer,
        title: '${session.targetHours}h 단식 진행 중',
        subtitle: '경과 $h:$m',
        done: false,
        trailing: OutlinedButton(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12)),
          onPressed: onStop,
          child: const Text('종료'),
        ),
      );
    }
    if (fastingDone) {
      return _SheetRow(
        icon: Icons.timer,
        title: '단식',
        subtitle: '오늘 완료',
        done: true,
        trailing: Icon(Icons.check_circle, color: theme.colorScheme.primary),
      );
    }
    return Row(
      children: [
        Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        const Expanded(child: Text('단식')),
        _SmallBtn(label: '14h', onTap: () => onStart(14)),
        const SizedBox(width: 6),
        _SmallBtn(label: '24h', onTap: () => onStart(24)),
      ],
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }
}
