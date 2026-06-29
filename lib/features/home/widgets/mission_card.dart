import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/program/mission_checker.dart';
import '../../../core/providers.dart';
import '../../../data/models/daily_log.dart';
import '../../fasting/fasting_controller.dart';
import '../../meals/meals_controller.dart';
import '../daily_log_controller.dart';

/// 오늘의 미션 카드.
/// - 조건이 충족된 미션은 자동으로 체크되고 DB에 저장됩니다.
/// - 자동 체크 항목은 번개 아이콘으로 구분되며 수동으로 토글할 수 있습니다.
class MissionCard extends ConsumerStatefulWidget {
  const MissionCard({super.key, required this.mission});
  final List<String> mission;

  @override
  ConsumerState<MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends ConsumerState<MissionCard> {
  // 이미 저장 요청을 보낸 라벨 — 중복 저장 방지.
  final Set<String> _savingNow = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final log = ref.watch(dailyLogControllerProvider).valueOrNull;
    final meals = ref.watch(mealsControllerProvider).valueOrNull ?? [];
    final fastingSession = ref.watch(fastingControllerProvider).valueOrNull;
    final weeklyStats = ref.watch(weeklyStatsProvider).valueOrNull;

    final missionDone = log?.missionDone.toSet() ?? <String>{};

    // 자동 달성 여부 계산
    final ctx = MissionContext(
      log: log ?? DailyLog.empty(DateTime.now()),
      shakeCount: shakeCountOf(meals),
      meals: meals,
      fastingSession: fastingSession,
      weeklyExerciseCount: weeklyStats?.exerciseCount ?? 0,
      weeklyFasting24Count: weeklyStats?.fasting24Count ?? 0,
    );

    final autoChecked = <String>{};
    for (final m in widget.mission) {
      if (autoCheckMission(m, ctx)) autoChecked.add(m);
    }

    // 자동 달성됐지만 아직 저장 안 된 항목을 프레임 종료 후 저장
    if (log != null) {
      final toSave = autoChecked.difference(missionDone);
      if (toSave.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final label in toSave) {
            if (!_savingNow.contains(label)) {
              _savingNow.add(label);
              ref
                  .read(dailyLogControllerProvider.notifier)
                  .setMissionChecked(label)
                  .catchError((_) {})
                  .whenComplete(() => _savingNow.remove(label));
            }
          }
        });
      }
    }

    final effectiveDone = missionDone.union(autoChecked);
    final doneCount = widget.mission.where(effectiveDone.contains).length;

    Future<void> toggle(String label) async {
      try {
        await ref
            .read(dailyLogControllerProvider.notifier)
            .toggleMission(label);
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
                Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('오늘의 미션', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('$doneCount/${widget.mission.length}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 4),
            for (final m in widget.mission)
              _MissionRow(
                label: m,
                done: effectiveDone.contains(m),
                isAuto: autoChecked.contains(m),
                onTap: () => toggle(m),
              ),
            if (autoChecked.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.bolt,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '자동 달성',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.label,
    required this.done,
    required this.isAuto,
    required this.onTap,
  });

  final String label;
  final bool done;
  final bool isAuto; // 자동 달성 여부
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = done ? theme.colorScheme.primary : theme.colorScheme.outline;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘: 자동=번개, 수동=체크, 미완료=빈 원
            Icon(
              done
                  ? (isAuto ? Icons.bolt : Icons.check_circle)
                  : Icons.radio_button_unchecked,
              size: 22,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: done
                    ? TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
