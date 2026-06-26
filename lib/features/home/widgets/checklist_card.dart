import 'package:flutter/material.dart';

import '../../../data/models/daily_log.dart';

/// 일일 체크리스트 카드 — 물·수면·단식·운동 + 달성률 시각화.
class ChecklistCard extends StatelessWidget {
  const ChecklistCard({
    super.key,
    required this.log,
    required this.onAddWater,
    required this.onSetSleep,
    required this.onToggleFasting,
    required this.onToggleExercise,
  });

  final DailyLog log;
  final ValueChanged<int> onAddWater;
  final ValueChanged<double> onSetSleep;
  final VoidCallback onToggleFasting;
  final VoidCallback onToggleExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (log.completionRate * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('오늘의 체크리스트',
                      style: theme.textTheme.titleMedium),
                ),
                _CompletionRing(rate: log.completionRate, percent: percent),
              ],
            ),
            const SizedBox(height: 16),

            // 물
            _WaterRow(log: log, onAddWater: onAddWater),
            const Divider(height: 28),

            // 수면
            _SleepRow(log: log, onSetSleep: onSetSleep),
            const Divider(height: 28),

            // 단식
            _ToggleRow(
              icon: Icons.timer_outlined,
              label: '단식',
              done: log.fastingDone,
              onTap: onToggleFasting,
            ),
            const SizedBox(height: 8),

            // 운동
            _ToggleRow(
              icon: Icons.fitness_center_outlined,
              label: '고강도 운동',
              done: log.exerciseDone,
              onTap: onToggleExercise,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.rate, required this.percent});
  final double rate;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: rate,
              strokeWidth: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text('$percent%', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _WaterRow extends StatelessWidget {
  const _WaterRow({required this.log, required this.onAddWater});
  final DailyLog log;
  final ValueChanged<int> onAddWater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio =
        (log.waterMl / DailyLog.waterTargetMl).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              log.waterDone
                  ? Icons.water_drop
                  : Icons.water_drop_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('물  ${log.waterMl} / ${DailyLog.waterTargetMl}ml'),
            ),
            if (log.waterDone)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: ratio, minHeight: 6),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => onAddWater(250),
              child: const Text('+250ml'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => onAddWater(500),
              child: const Text('+500ml'),
            ),
            const Spacer(),
            if (log.waterMl > 0)
              TextButton(
                onPressed: () => onAddWater(-log.waterMl),
                child: const Text('초기화'),
              ),
          ],
        ),
      ],
    );
  }
}

class _SleepRow extends StatelessWidget {
  const _SleepRow({required this.log, required this.onSetSleep});
  final DailyLog log;
  final ValueChanged<double> onSetSleep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const options = [5.0, 6.0, 7.0, 8.0, 9.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              log.sleepDone ? Icons.bedtime : Icons.bedtime_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('수면 (6시간 이상)')),
            if (log.sleepDone)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final h in options)
              ChoiceChip(
                label: Text(h >= 9 ? '9h+' : '${h.toInt()}h'),
                selected: log.sleepHours == h,
                onSelected: (_) => onSetSleep(h),
              ),
          ],
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
