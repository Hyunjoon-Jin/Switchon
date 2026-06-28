import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/meal_log.dart';
import '../community/community_controller.dart';
import '../community/nickname.dart';
import '../meals/history_screen.dart';
import '../meals/meal_detail_screen.dart';
import 'meal_stats.dart';
import 'stats.dart';
import 'stats_controller.dart';

/// 통계 대시보드 — 기간 토글 + 달성률/항목 + 식사·영양 추이.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final mealAsync = ref.watch(mealStatsProvider);
    final period = ref.watch(statsPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('통계'),
        actions: [
          IconButton(
            tooltip: '식사 기록 보기',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statsProvider);
          ref.invalidate(mealStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _PeriodToggle(
              period: period,
              onChanged: (d) =>
                  ref.read(statsPeriodProvider.notifier).state = d,
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'),
              data: (s) => _CompletionSection(
                s: s,
                onShare: () => _shareAchievement(context, ref, s),
              ),
            ),
            const SizedBox(height: 8),
            mealAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('$e'),
              data: (m) => _MealSection(stats: m),
            ),
            const SizedBox(height: 40),
          ],
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

/// 기간 토글 (1주 / 2주 / 4주).
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});
  final int period;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('1주')),
        ButtonSegment(value: 14, label: Text('2주')),
        ButtonSegment(value: 28, label: Text('4주')),
      ],
      selected: {period},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
    );
  }
}

// ============================ 달성/누적 섹션 ============================

class _CompletionSection extends StatelessWidget {
  const _CompletionSection({required this.s, required this.onShare});
  final StatsSummary s;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    if (s.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('아직 통계가 없어요.\n오늘부터 기록을 시작해 보세요!',
              textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(s: s),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onShare,
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
    );
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

/// 최근 N일 달성률 막대 추이.
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

  String _label(DateTime? d) => d == null ? '' : '${d.month}.${d.day}';
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

/// 항목별 달성 일수 (물·수면·단식·운동).
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
              _ItemRow(label: it.$1, days: it.$2, total: window, icon: it.$3),
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

/// 누적 지표 (전체 기간).
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

// ============================ 식사 · 영양 섹션 ============================

class _MealSection extends StatelessWidget {
  const _MealSection({required this.stats});
  final MealStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = stats;
    if (m.mealsCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.restaurant_outlined,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              const Expanded(child: Text('이 기간에는 식사 기록이 없어요.')),
            ],
          ),
        ),
      );
    }

    final maxMeals = m.mealCountTrend
        .map((e) => e.value)
        .fold<double>(1, (a, b) => b > a ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('식사 · 영양', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),

        // 식사 빈도(분석 여부와 무관하게 항상)
        _MetricBarsCard(
          title: '식사 빈도 (일별 끼니 수)',
          metrics: m.mealCountTrend,
          maxValue: maxMeals,
          color: theme.colorScheme.tertiary,
          footer: '총 ${m.mealsCount}끼 · 분석 ${m.analyzedCount}끼',
        ),

        if (!m.hasNutrition) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('아직 AI로 분석한 식사가 없어요.\n'
                        '식사를 AI 분석하면 칼로리·영양·점수 통계가 쌓여요.'),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          _AvgNutritionCard(m: m),
          const SizedBox(height: 16),
          _MetricBarsCard(
            title: '칼로리 추이 (일별 kcal)',
            metrics: m.calorieTrend,
            maxValue: m.calorieTrend
                .map((e) => e.value)
                .fold<double>(1, (a, b) => b > a ? b : a),
            color: theme.colorScheme.primary,
            footer: '평균 ${m.avgCalories} kcal / 끼',
          ),
          const SizedBox(height: 16),
          _VerdictCard(m: m),
          const SizedBox(height: 16),
          _MetricBarsCard(
            title: 'AI 점수 추이 (일별 평균)',
            metrics: m.scoreTrend,
            maxValue: 100,
            color: theme.colorScheme.secondary,
            footer: '평균 ${m.avgScore}점',
          ),
          const SizedBox(height: 16),
          _RecentAnalyzedCard(meals: m.recentAnalyzed),
        ],

        const SizedBox(height: 8),
        Text('※ 칼로리·영양은 사진/메뉴 기반 AI 추정치입니다.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// 평균 칼로리 + 탄·단·지 + 비율 막대.
class _AvgNutritionCard extends StatelessWidget {
  const _AvgNutritionCard({required this.m});
  final MealStats m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (rc, rp, rf) = m.macroRatio;
    final items = <(String, String)>[
      ('평균 칼로리', '${m.avgCalories} kcal'),
      ('탄수화물', '${m.avgCarbs} g'),
      ('단백질', '${m.avgProtein} g'),
      ('지방', '${m.avgFat} g'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('평균 영양 (분석 1끼 기준)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final it in items)
                  Column(
                    children: [
                      Text(it.$2,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(it.$1,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('탄·단·지 비율', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: (rc * 1000).round().clamp(1, 1000),
                    child:
                        Container(height: 14, color: theme.colorScheme.primary),
                  ),
                  Expanded(
                    flex: (rp * 1000).round().clamp(1, 1000),
                    child: Container(
                        height: 14, color: theme.colorScheme.tertiary),
                  ),
                  Expanded(
                    flex: (rf * 1000).round().clamp(1, 1000),
                    child:
                        Container(height: 14, color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              children: [
                _Legend(
                    color: theme.colorScheme.primary,
                    label: '탄수 ${(rc * 100).round()}%'),
                _Legend(
                    color: theme.colorScheme.tertiary,
                    label: '단백 ${(rp * 100).round()}%'),
                _Legend(
                    color: theme.colorScheme.error,
                    label: '지방 ${(rf * 100).round()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 단계 부합률 (적합/주의/단계제한).
class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.m});
  final MealStats m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total =
        (m.fitCount + m.cautionCount + m.violationCount).clamp(1, 1 << 30);
    final fitC = theme.colorScheme.primary;
    final cauC = Colors.orange.shade700;
    final vioC = theme.colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('단계 부합률 (분석 ${m.analyzedCount}끼)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: m.fitCount.clamp(0, 1 << 30),
                    child: Container(height: 16, color: fitC),
                  ),
                  Expanded(
                    flex: m.cautionCount.clamp(0, 1 << 30),
                    child: Container(height: 16, color: cauC),
                  ),
                  Expanded(
                    flex: m.violationCount.clamp(0, 1 << 30),
                    child: Container(height: 16, color: vioC),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Legend(
                    color: fitC,
                    label:
                        '적합 ${m.fitCount} (${(m.fitCount / total * 100).round()}%)'),
                _Legend(color: cauC, label: '주의 ${m.cautionCount}'),
                _Legend(color: vioC, label: '단계제한 ${m.violationCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 일별 단일 지표 막대 카드(칼로리·점수·식사수 공용).
class _MetricBarsCard extends StatelessWidget {
  const _MetricBarsCard({
    required this.title,
    required this.metrics,
    required this.maxValue,
    required this.color,
    this.footer,
  });
  final String title;
  final List<DayMetric> metrics;
  final double maxValue;
  final Color color;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = maxValue <= 0 ? 1.0 : maxValue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in metrics)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: FractionallySizedBox(
                                alignment: Alignment.bottomCenter,
                                heightFactor: d.has
                                    ? (d.value / max).clamp(0.04, 1.0)
                                    : 0.03,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: d.has
                                        ? color
                                        : theme.colorScheme
                                            .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metrics.isNotEmpty
                      ? '${metrics.first.date.month}.${metrics.first.date.day}'
                      : '',
                  style: theme.textTheme.bodySmall,
                ),
                Text('오늘', style: theme.textTheme.bodySmall),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(footer!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 최근 분석한 식사 리스트.
class _RecentAnalyzedCard extends StatelessWidget {
  const _RecentAnalyzedCard({required this.meals});
  final List<MealLog> meals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (meals.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text('최근 분석한 식사', style: theme.textTheme.titleMedium),
            ),
            for (final meal in meals)
              ListTile(
                dense: true,
                leading: _ScoreBadge(score: meal.ai!.score),
                title: Text(
                  '${meal.slotLabel} · ${_time(meal.loggedAt)}',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  meal.ai!.foods.isNotEmpty
                      ? meal.ai!.foods
                      : (meal.memo ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: meal.ai!.calories != null
                    ? Text('${meal.ai!.calories} kcal',
                        style: theme.textTheme.bodySmall)
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MealDetailScreen(meal: meal),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime t) =>
      '${t.month}.${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = score >= 80
        ? theme.colorScheme.primary
        : (score >= 50 ? Colors.orange.shade700 : theme.colorScheme.error);
    return CircleAvatar(
      radius: 18,
      backgroundColor: c.withOpacity(0.15),
      child: Text('$score',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: c, fontWeight: FontWeight.w700)),
    );
  }
}
