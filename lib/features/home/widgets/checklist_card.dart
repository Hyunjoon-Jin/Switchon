import 'package:flutter/material.dart';

import '../../../data/models/daily_log.dart';

/// 가로로 나란히 두는 물 버튼용 — 전역 테마의 '가로 꽉 채움'을 무력화(폭 제한).
final ButtonStyle _waterBtnStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 16),
);

/// 일일 체크리스트 카드 — 물·수면·단식·운동 + 달성률 시각화.
class ChecklistCard extends StatelessWidget {
  const ChecklistCard({
    super.key,
    required this.log,
    required this.onAddWater,
    required this.onSetSleepStart,
    required this.onSetSleepEnd,
    required this.onToggleFasting,
    required this.onToggleExercise,
  });

  final DailyLog log;
  final ValueChanged<int> onAddWater;
  final ValueChanged<int> onSetSleepStart; // 잠든 시각(분)
  final ValueChanged<int> onSetSleepEnd; // 일어난 시각(분)
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
            _SleepRow(
              log: log,
              onSetStart: onSetSleepStart,
              onSetEnd: onSetSleepEnd,
            ),
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
              style: _waterBtnStyle,
              onPressed: () => onAddWater(250),
              child: const Text('+250ml'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: _waterBtnStyle,
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

/// 수면: 잠든 시각·일어난 시각을 고르면 자동으로 수면 시간 계산(자정 넘김 포함).
class _SleepRow extends StatelessWidget {
  const _SleepRow({
    required this.log,
    required this.onSetStart,
    required this.onSetEnd,
  });
  final DailyLog log;
  final ValueChanged<int> onSetStart;
  final ValueChanged<int> onSetEnd;

  String _fmt(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _durationLabel() {
    final h = log.sleepHours;
    if (!log.hasSleepTimes || h == null) return '';
    final hours = h.floor();
    final mins = ((h - hours) * 60).round();
    return mins == 0 ? '총 $hours시간' : '총 $hours시간 $mins분';
  }

  Future<void> _pick(
    BuildContext context,
    int? currentMinutes,
    ValueChanged<int> onPicked,
    int fallback,
  ) async {
    final init = currentMinutes ?? fallback;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init ~/ 60, minute: init % 60),
    );
    if (picked != null) onPicked(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: '잠든 시각',
                value: log.sleepStartMinutes == null
                    ? null
                    : _fmt(log.sleepStartMinutes!),
                onTap: () => _pick(
                    context, log.sleepStartMinutes, onSetStart, 23 * 60),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 18),
            ),
            Expanded(
              child: _TimeButton(
                label: '일어난 시각',
                value: log.sleepEndMinutes == null
                    ? null
                    : _fmt(log.sleepEndMinutes!),
                onTap: () =>
                    _pick(context, log.sleepEndMinutes, onSetEnd, 7 * 60),
              ),
            ),
          ],
        ),
        if (log.hasSleepTimes) ...[
          const SizedBox(height: 8),
          Text(
            _durationLabel(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value ?? '선택',
            style: theme.textTheme.titleMedium?.copyWith(
              color: value == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
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
