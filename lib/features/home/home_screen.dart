import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/stage_engine.dart';
import '../../core/providers.dart';
import '../../data/models/profile.dart';
import '../branch/branch_check_screen.dart';
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
              onSetSleep: (h) => _guard(
                context,
                () => ref
                    .read(dailyLogControllerProvider.notifier)
                    .setSleepHours(h),
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
          _FoodGuide(allowed: stage.allowedFoods, forbidden: stage.forbiddenFoods),

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

class _FoodGuide extends StatelessWidget {
  const _FoodGuide({required this.allowed, required this.forbidden});
  final List<String> allowed;
  final List<String> forbidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 단계의 식품 가이드', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _chips(context, '허용', allowed, theme.colorScheme.primary),
            const SizedBox(height: 12),
            _chips(context, '주의·제한', forbidden, theme.colorScheme.error),
          ],
        ),
      ),
    );
  }

  Widget _chips(
      BuildContext context, String label, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: color)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in items)
              Chip(
                label: Text(i),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: color.withOpacity(0.4)),
              ),
          ],
        ),
      ],
    );
  }
}
