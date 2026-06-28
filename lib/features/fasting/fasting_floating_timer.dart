import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/glass.dart';
import 'fasting_controller.dart';

/// 단식이 진행 중일 때 화면 우측 하단에 떠 있는 글라스 타이머 칩.
/// 1초마다 남은 시간을 갱신하며, 탭하면 단식 탭으로 이동한다.
class FastingFloatingTimer extends ConsumerStatefulWidget {
  const FastingFloatingTimer({super.key, required this.onTap});

  /// 탭 시 동작(보통 단식 탭으로 전환).
  final VoidCallback onTap;

  @override
  ConsumerState<FastingFloatingTimer> createState() =>
      _FastingFloatingTimerState();
}

class _FastingFloatingTimerState extends ConsumerState<FastingFloatingTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(fastingControllerProvider).valueOrNull;
    if (session == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final now = DateTime.now();
    final reached = session.reachedGoalAt(now);
    final progress = session.progressAt(now);
    final remaining = session.remainingAt(now);
    final elapsed = session.elapsedAt(now);

    final mainText = reached ? '목표 달성 🎉' : _fmt(remaining);
    final subText = reached
        ? '${_fmtShort(elapsed)} 경과'
        : '${session.targetHours}시간 단식';

    return GlassCard(
      onTap: widget.onTap,
      radius: 26,
      blur: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: reached ? 1.0 : progress.clamp(0.0, 1.0),
                  strokeWidth: 3,
                  backgroundColor: theme.colorScheme.onSurface.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(
                      reached ? theme.colorScheme.primary : theme.colorScheme.secondary),
                ),
                Icon(
                  reached ? Icons.check : Icons.timer_outlined,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mainText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                subText,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// h:mm:ss (남은 시간).
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$h:$mm:$ss';
  }

  /// 경과 시간 짧은 표기(h시간 m분).
  String _fmtShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '$h시간 $m분' : '$m분';
  }
}
