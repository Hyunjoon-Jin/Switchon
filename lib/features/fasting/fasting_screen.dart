import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fasting_session.dart';
import 'fasting_controller.dart';

/// 단식 타이머 화면 (14h / 24h). 활성 세션은 1초 단위 라이브 카운트다운.
class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final fastingAsync = ref.watch(fastingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('단식 타이머')),
      body: fastingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (session) => session == null
            ? _StartView(
                onStart: (h) =>
                    ref.read(fastingControllerProvider.notifier).start(h),
              )
            : _ActiveView(
                session: session,
                now: _now,
                fmt: _fmt,
                onStop: (canceled) => _confirmStop(session, canceled),
              ),
      ),
    );
  }

  Future<void> _confirmStop(FastingSession session, bool reachedGoal) async {
    if (!reachedGoal) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('단식을 중단할까요?'),
          content: const Text('목표 시간 전이에요. 무리하지 않는 것도 중요해요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('계속하기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('중단'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref
        .read(fastingControllerProvider.notifier)
        .stop(canceled: !reachedGoal);
  }
}

class _StartView extends StatelessWidget {
  const _StartView({required this.onStart});
  final ValueChanged<int> onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('단식을 시작해요', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '목표 시간을 고르면 종료 시각에 알림을 보내드려요.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => onStart(14),
            child: const Text('14시간 단식 시작'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onStart(24),
            child: const Text('24시간 단식 시작'),
          ),
        ],
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({
    required this.session,
    required this.now,
    required this.fmt,
    required this.onStop,
  });

  final FastingSession session;
  final DateTime now;
  final String Function(Duration) fmt;
  final ValueChanged<bool> onStop; // bool: 목표 달성 여부

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = session.elapsedAt(now);
    final remaining = session.remainingAt(now);
    final reached = session.reachedGoalAt(now);
    final progress = session.progressAt(now);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${session.targetHours}시간 단식',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reached ? '목표 달성!' : '경과',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: reached
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(fmt(elapsed),
                        style: theme.textTheme.displaySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            reached ? '목표 시간을 채웠어요 👏' : '남은 시간  ${fmt(remaining)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '종료 예정  ${_hm(session.targetEnd)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: () => onStop(reached),
            child: Text(reached ? '단식 완료' : '단식 중단'),
          ),
        ],
      ),
    );
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
