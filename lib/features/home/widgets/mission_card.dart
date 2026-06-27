import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../daily_log_controller.dart';

/// 오늘의 미션 카드 — 각 항목을 눌러 체크할 수 있어요(오늘 기준 저장).
class MissionCard extends ConsumerWidget {
  const MissionCard({super.key, required this.mission});
  final List<String> mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final log = ref.watch(dailyLogControllerProvider).valueOrNull;
    final done = log?.missionDone.toSet() ?? <String>{};
    final doneCount = mission.where(done.contains).length;

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
                Text('$doneCount/${mission.length}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 4),
            for (final m in mission)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => toggle(m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        done.contains(m)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 22,
                        color: done.contains(m)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          m,
                          style: done.contains(m)
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
              ),
          ],
        ),
      ),
    );
  }
}
