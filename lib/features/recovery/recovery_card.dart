import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/glass.dart';
import '../../data/models/recovery.dart';
import '../home/daily_log_controller.dart';
import '../stats/stats_controller.dart';
import 'recovery_controller.dart';

/// 미준수 감지 시 홈 상단에 노출되는 회복 카드.
/// 비난 대신 격려 + 보정 팁 + 계획 유연 조정(하루 연장/일시정지) + AI 코칭.
class RecoveryCard extends ConsumerWidget {
  const RecoveryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signal = ref.watch(recoverySignalProvider).valueOrNull;
    if (signal == null) return const SizedBox.shrink();
    final dismissed = ref.watch(dismissedRecoveryProvider);
    if (dismissed.contains(signal.dismissKey)) return const SizedBox.shrink();

    final theme = Theme.of(context);

    void dismiss() {
      ref.read(dismissedRecoveryProvider.notifier).update(
            (s) => {...s, signal.dismissKey},
          );
    }

    Future<void> log(String resolution) async {
      try {
        await ref
            .read(supabaseServiceProvider)
            .logRecoveryEvent(signal.kind.id, resolution: resolution);
      } catch (_) {/* 기록 실패는 조용히 무시 */}
    }

    void snack(String msg) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }

    Future<void> onRestart() async {
      await log('restart');
      dismiss();
      snack('좋아요, 오늘부터 다시 가볍게 이어가요 🌱');
    }

    Future<void> onExtend() async {
      final profile = ref.read(profileProvider).valueOrNull;
      if (profile == null) return;
      try {
        await ref.read(supabaseServiceProvider).extendProgram(profile, 1);
        ref.invalidate(profileProvider);
        await log('extend');
        dismiss();
        snack('일정을 하루 늦췄어요. 같은 단계를 천천히 더 가져가요.');
      } catch (_) {
        snack('조정에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    }

    Future<void> onPause() async {
      try {
        await ref.read(supabaseServiceProvider).pauseProgram(DateTime.now());
        ref.invalidate(profileProvider);
        ref.invalidate(dailyLogControllerProvider);
        await log('pause');
        dismiss();
        snack('잠시 멈출게요. 준비되면 메뉴에서 재개하세요.');
      } catch (_) {
        snack('일시정지에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    }

    Future<void> onCoach() async {
      await _showCoach(context, ref, signal);
      await log('coach');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(signal.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    await log('dismiss');
                    dismiss();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(signal.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            for (final tip in signal.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(tip, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  style: _btn,
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('오늘 다시 시작'),
                ),
                if (signal.suggestAdjust) ...[
                  OutlinedButton.icon(
                    style: _btn,
                    onPressed: onExtend,
                    icon: const Icon(Icons.event_repeat, size: 18),
                    label: const Text('하루 늦추기'),
                  ),
                  OutlinedButton.icon(
                    style: _btn,
                    onPressed: onPause,
                    icon: const Icon(Icons.pause_circle_outline, size: 18),
                    label: const Text('잠시 멈춤'),
                  ),
                ],
                TextButton.icon(
                  style: _btn,
                  onPressed: onCoach,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('AI 코칭'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _btn =
      TextButton.styleFrom(minimumSize: const Size(0, 40));

  Future<void> _showCoach(
      BuildContext context, WidgetRef ref, RecoverySignal signal) async {
    // 로딩 다이얼로그
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String body;
    try {
      final pos = ref.read(currentStagePositionProvider);
      final stats = await ref.read(statsProvider.future);
      body = await ref.read(supabaseServiceProvider).recoveryCoach(
            kind: signal.kind.id,
            week: pos?.week ?? 1,
            day: pos?.day ?? 1,
            stageTitle: pos?.stage.title ?? '',
            avgCompletion: stats.avgCompletion,
            recentViolations: stats.violations,
          );
    } catch (_) {
      // 폴백: 규칙 기반 팁을 모아 안내(AI 함수 미배포/실패 시).
      body = '${signal.message}\n\n• ${signal.tips.join('\n• ')}';
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // 로딩 닫기

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 회복 코칭'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              const SizedBox(height: 12),
              Text('※ 참고용 코칭이며 의학적 조언이 아닙니다.',
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
