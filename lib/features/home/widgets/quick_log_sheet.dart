import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/daily_log.dart';
import '../daily_log_controller.dart';

/// 어떤 탭에서든 '+ 기록' FAB으로 열리는 빠른 기록 바텀 시트.
/// (단식은 단식 탭에서 관리하므로 여기서는 고강도 운동만 빠르게 체크합니다.)
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
