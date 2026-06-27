import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../community/community_controller.dart';
import '../community/nickname.dart';
import 'stats.dart';
import 'stats_controller.dart';

/// 통계 대시보드 — 달성률 추이 + 항목별 달성 + 누적 지표.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(statsProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (s.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('아직 통계가 없어요.\n오늘부터 기록을 시작해 보세요!',
                        textAlign: TextAlign.center),
                  ),
                )
              else ...[
                _SummaryRow(s: s),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _shareAchievement(context, ref, s),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('성과 자랑하기'),
                ),
                const SizedBox(height: 20),
                _TrendCard(trend: s.trend),
                const SizedBox(height: 16),
                _ItemDaysCard(s: s),
                const SizedBox(height: 16),
                _TotalsCard(s: s),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAchievement(
      BuildContext context, WidgetRef ref, StatsSummary s) async {
    final name = await ensureNickname(context, ref);
    if (name == null || !context.mounted) return;
    final week = ref.read(currentStagePositionProvider)?.week ?? 1;
    final title = s.currentStreak >= 3
        ? '${s.currentStreak}일 연속 달성 중! 🔥'
        : '스위치온 $week주차 진행 중!';
    final lines = <String>[
      '평균 달성률 ${(s.avgCompletion * 100).round()}%',
      '단식 ${s.completedFastings}회 완주',
      '연속 ${s.currentStreak}일',
    ];
    try {
      await ref.read(communityServiceProvider).createAchievementPost(
            week: week,
            authorName: name,
            title: title,
            lines: lines,
          );
      ref.invalidate(feedProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('성과를 커뮤니티에 공유했어요 🎉')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.s});
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final pct = (s.avgCompletion * 100).round();
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: '평균 달성률',
            value: '$pct%',
            icon: Icons.donut_large,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: '기록한 날',
            value: '${s.daysLogged}일',
            icon: Icons.event_available_outlined,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// 최근 N일 달성률 막대 추이 (커스텀, 의존성 없음).
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});
  final List<DayBar> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('달성률 추이 (최근 ${trend.length}일)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bar in trend)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _Bar(bar: bar),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_label(trend.isNotEmpty ? trend.first.date : null),
                    style: theme.textTheme.bodySmall),
                Text('오늘', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(DateTime? d) =>
      d == null ? '' : '${d.month}.${d.day}';
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar});
  final DayBar bar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = bar.logged
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: bar.logged ? bar.rate.clamp(0.04, 1.0) : 0.04,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 항목별 달성 일수 (물·수면·단식·운동) — 윈도우 기준.
class _ItemDaysCard extends StatelessWidget {
  const _ItemDaysCard({required this.s});
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final window = s.trend.length;
    final items = [
      ('물 2L', s.waterDays, Icons.water_drop_outlined),
      ('수면 6h+', s.sleepDays, Icons.bedtime_outlined),
      ('단식', s.fastingDays, Icons.timer_outlined),
      ('운동', s.exerciseDays, Icons.fitness_center_outlined),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('항목별 달성 (최근 $window일)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final it in items) ...[
              _ItemRow(
                label: it.$1,
                days: it.$2,
                total: window,
                icon: it.$3,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.label,
    required this.days,
    required this.total,
    required this.icon,
  });
  final String label;
  final int days;
  final int total;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : days / total;
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: ratio, minHeight: 8),
          ),
        ),
        const SizedBox(width: 10),
        Text('$days/$total', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 누적 지표 (전체 기간): 셰이크·단식 완료·규칙 위반.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.s});
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('누적', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '${s.totalShakes}',
                    label: '셰이크',
                    icon: Icons.local_drink_outlined,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${s.completedFastings}',
                    label: '단식 완료',
                    icon: Icons.timer,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${s.violations}',
                    label: '규칙 위반',
                    icon: Icons.info_outline,
                    highlight: s.violations > 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });
  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        highlight ? theme.colorScheme.error : theme.colorScheme.primary;
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.headlineSmall),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
