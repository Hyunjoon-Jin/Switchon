import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/stage_engine.dart';
import '../../core/program/switchon_program.dart';
import '../../core/providers.dart';
import '../../data/models/profile.dart';
import '../branch/branch_check_screen.dart';
import '../meal_guide/meal_guide_screen.dart';
import '../reminders/reminders_screen.dart';
import 'daily_log_controller.dart';
import 'widgets/checklist_card.dart';
import 'widgets/mission_card.dart';

/// 홈 — 오늘의 단계(주차/일차) + 미션 + 일일 체크리스트 + 식품 가이드.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘'),
        actions: [
          profileAsync.maybeWhen(
            data: (p) => p == null
                ? const SizedBox.shrink()
                : _OverflowMenu(profile: p),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('프로필을 불러올 수 없습니다.'));
          }
          return _Today(profile: profile);
        },
      ),
    );
  }
}

class _Today extends ConsumerWidget {
  const _Today({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pos = StageEngine.compute(
      startDate: profile.startDate ?? DateTime.now(),
      status: profile.status,
      pausedAt: profile.pausedAt,
      today: DateTime.now(),
    );
    final stage = pos.stage;
    final logAsync = ref.watch(dailyLogControllerProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileProvider);
        ref.invalidate(dailyLogControllerProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (pos.isCompleted) const _CompletedBanner(),
          if (pos.isPaused) const _PausedBanner(),
          _WeeklyCheckCard(stageId: stage.id),
          Text(
            '${pos.week}주차  ·  ${pos.day}일차',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(stage.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          _ProgramProgress(programDay: pos.programDay, totalDays: pos.totalDays),
          const SizedBox(height: 20),

          // 오늘의 체크리스트 (P1 핵심)
          logAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('체크리스트를 불러오지 못했어요.\n$e'),
              ),
            ),
            data: (log) => ChecklistCard(
              log: log,
              onAddWater: (ml) => _guard(
                context,
                () => ref.read(dailyLogControllerProvider.notifier).addWater(ml),
              ),
              onSetSleepStart: (m) => _guard(
                context,
                () => ref
                    .read(dailyLogControllerProvider.notifier)
                    .setSleepTimes(startMinutes: m),
              ),
              onSetSleepEnd: (m) => _guard(
                context,
                () => ref
                    .read(dailyLogControllerProvider.notifier)
                    .setSleepTimes(endMinutes: m),
              ),
              onToggleFasting: () => _guard(
                context,
                () => ref
                    .read(dailyLogControllerProvider.notifier)
                    .toggleFasting(),
              ),
              onToggleExercise: () => _guard(
                context,
                () => ref
                    .read(dailyLogControllerProvider.notifier)
                    .toggleExercise(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          MissionCard(mission: stage.mission),
          const SizedBox(height: 16),
          _MealGuideCard(stage: stage),

          if (stage.notes != null) ...[
            const SizedBox(height: 16),
            _NoteCard(text: stage.notes!),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              '단식/셰이크 타이머 · 식단 기록은 곧 추가됩니다 (P2)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }
}

class _ProgramProgress extends StatelessWidget {
  const _ProgramProgress({required this.programDay, required this.totalDays});
  final int programDay;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (programDay / totalDays).clamp(0.0, 1.0),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '전체 진행  $programDay / $totalDays일',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = profile.status == 'paused';
    return PopupMenuButton<String>(
      onSelected: (value) async {
        final service = ref.read(supabaseServiceProvider);
        switch (value) {
          case 'reminders':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RemindersScreen(),
              ),
            );
            break;
          case 'pause':
            await service.pauseProgram(DateTime.now());
            ref.invalidate(profileProvider);
            break;
          case 'resume':
            await service.resumeProgram(profile, DateTime.now());
            ref.invalidate(profileProvider);
            break;
          case 'signout':
            await ref.read(authServiceProvider).signOut();
            ref.invalidate(profileProvider);
            ref.invalidate(dailyLogControllerProvider);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'reminders', child: Text('알림 설정')),
        if (paused)
          const PopupMenuItem(value: 'resume', child: Text('프로그램 재개'))
        else
          const PopupMenuItem(value: 'pause', child: Text('프로그램 일시정지')),
        const PopupMenuItem(value: 'signout', child: Text('로그아웃')),
      ],
    );
  }
}

/// 주 마지막 날 + 아직 점검 안 했을 때 노출되는 주차 점검 카드.
class _WeeklyCheckCard extends ConsumerWidget {
  const _WeeklyCheckCard({required this.stageId});
  final String stageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(weeklyCheckDueProvider).valueOrNull;
    if (due == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: theme.colorScheme.tertiaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    BranchCheckScreen(week: due, stageId: stageId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.checklist_rtl,
                    color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$due주차 점검할 시간이에요',
                          style: theme.textTheme.titleMedium?.copyWith(
                              color:
                                  theme.colorScheme.onTertiaryContainer)),
                      Text('이번 주를 돌아보고 다음 단계를 안내받으세요',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme
                                  .colorScheme.onTertiaryContainer)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onTertiaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.pause_circle_outline,
                color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '일시정지 중이에요. 일차는 멈춰 있어요 — 준비되면 메뉴에서 재개하세요.',
                style:
                    TextStyle(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.celebration_outlined,
                color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '4주 프로그램을 끝까지 완주했어요. 정말 잘하셨어요! 👏',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 홈의 식단 요약 카드 — 끼니별 한 줄 + 전체 가이드로 이동.
class _MealGuideCard extends StatelessWidget {
  const _MealGuideCard({required this.stage});
  final StageRule stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mp = stage.mealPlan;
    final rows = <(IconData, String, String?)>[
      (Icons.local_drink_outlined, '셰이크', mp.shake),
      (Icons.lunch_dining_outlined, '점심', mp.lunch),
      (Icons.dinner_dining_outlined, '저녁', mp.dinner),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('오늘의 식단', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final r in rows)
              if (r.$3 != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.$1, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child:
                            Text(r.$2, style: theme.textTheme.labelMedium),
                      ),
                      Expanded(
                        child: Text(r.$3!,
                            style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MealGuideScreen(stage: stage),
                  ),
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('식단 가이드 · 예시 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
