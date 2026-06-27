import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/public_stat.dart';
import '../community/community_controller.dart';
import '../community/post_detail_screen.dart';
import '../stats/stats_controller.dart';

/// 공개 프로필 — 닉네임·현재 주차·공개 통계·작성글.
/// 본인 프로필이면 '통계 공개' 토글 제공(기본 비공개).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.userId, this.displayName});
  final String userId;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myId = ref.read(supabaseServiceProvider).currentUser?.id;
    final isMe = myId == userId;
    final statAsync = ref.watch(publicStatProvider(userId));
    final postsAsync = ref.watch(userPostsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(displayName ?? '프로필')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicStatProvider(userId));
          ref.invalidate(userPostsProvider(userId));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                (displayName ?? '익명').characters.first,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(displayName ?? '익명',
                  style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 20),

            if (isMe)
              _MyStatsSection(userId: userId)
            else
              statAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (stat) => stat == null || !stat.isPublic
                    ? _PrivateNote(theme: theme)
                    : _StatsCard(stat: stat),
              ),

            const SizedBox(height: 24),
            Text('작성한 글', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (posts) => posts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('아직 작성한 글이 없어요.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    )
                  : Column(
                      children: [
                        for (final p in posts)
                          Card(
                            child: ListTile(
                              leading: Icon(p.isAchievement
                                  ? Icons.emoji_events_outlined
                                  : Icons.article_outlined),
                              title: Text(
                                p.isAchievement
                                    ? p.achievementTitle
                                    : p.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PostDetailScreen(post: p),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 본인 프로필: 내 통계 + 공개 토글.
class _MyStatsSection extends ConsumerWidget {
  const _MyStatsSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(statsProvider);
    final publicAsync = ref.watch(publicStatProvider(userId));
    final isPublic = publicAsync.valueOrNull?.isPublic ?? false;

    Future<void> setPublic(bool value) async {
      final stats = await ref.read(statsProvider.future);
      final pos = ref.read(currentStagePositionProvider);
      final profile = ref.read(profileProvider).valueOrNull;
      await ref.read(communityServiceProvider).upsertMyPublicStats(
            displayName: profile?.displayName,
            currentWeek: pos?.week,
            avgCompletion: stats.avgCompletion,
            fastingCompleted: stats.completedFastings,
            currentStreak: stats.currentStreak,
            isPublic: value,
          );
      ref.invalidate(publicStatProvider(userId));
      ref.invalidate(leaderboardProvider);
    }

    return Column(
      children: [
        statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (s) => _StatsCard(
            stat: PublicStat(
              userId: userId,
              avgCompletion: s.avgCompletion,
              fastingCompleted: s.completedFastings,
              currentStreak: s.currentStreak,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: SwitchListTile(
            value: isPublic,
            onChanged: setPublic,
            title: const Text('통계 공개'),
            subtitle: const Text('켜면 같은 주차 그룹·프로필에서 내 요약 통계가 보여요. '
                '(매끼 식단 등 상세 기록은 공개되지 않아요)'),
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stat});
  final PublicStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      ('평균 달성률', '${stat.avgPercent}%', Icons.donut_large),
      ('단식 완주', '${stat.fastingCompleted}회', Icons.timer_outlined),
      ('연속 달성', '${stat.currentStreak}일', Icons.local_fire_department_outlined),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final i in items)
              Column(
                children: [
                  Icon(i.$3, color: theme.colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(i.$2, style: theme.textTheme.titleMedium),
                  Text(i.$1,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivateNote extends StatelessWidget {
  const _PrivateNote({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            const Expanded(child: Text('이 사용자는 통계를 비공개로 두었어요.')),
          ],
        ),
      ),
    );
  }
}
