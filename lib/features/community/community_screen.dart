import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../data/models/community.dart';
import '../social/profile_screen.dart';
import 'community_controller.dart';
import 'nickname.dart';
import 'post_detail_screen.dart';

/// 커뮤니티 — 같은 주차 그룹 피드 + 랭킹.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  int _tab = 0; // 0 피드 / 1 랭킹

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(feedWeekProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$week주차 그룹'),
        actions: [
          IconButton(
            tooltip: '내 프로필',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              final me = ref.read(supabaseServiceProvider).currentUser?.id;
              final name = ref.read(profileProvider).valueOrNull?.displayName;
              if (me == null) return;
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(userId: me, displayName: name),
              ));
            },
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _compose(context, week),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('글쓰기'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('피드'), icon: Icon(Icons.dynamic_feed_outlined)),
                ButtonSegment(value: 1, label: Text('랭킹'), icon: Icon(Icons.leaderboard_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: _tab == 0 ? const _FeedView() : _LeaderboardView(week: week),
          ),
        ],
      ),
    );
  }

  Future<void> _compose(BuildContext context, int week) async {
    final name = await ensureNickname(context, ref);
    if (name == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeSheet(week: week, authorName: name),
    );
  }
}

class _FeedView extends ConsumerWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (feedState) {
        final items = feedState.items;
        final newCount = feedState.newCount;
        return RefreshIndicator(
          onRefresh: () => ref.read(feedProvider.notifier).refresh(),
          child: Column(
            children: [
              // 실시간 새 게시글 알림 배너
              if (newCount > 0)
                _NewPostsBanner(count: newCount),
              Expanded(
                child: items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '아직 글이 없어요.\n같은 주차 동료들에게 첫 인사를 건네보세요!',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _PostCard(item: items[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 실시간으로 도착한 새 게시글 알림 배너.
class _NewPostsBanner extends ConsumerWidget {
  const _NewPostsBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => ref.read(feedProvider.notifier).clearNewCount(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: theme.colorScheme.primaryContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fiber_new_rounded,
                size: 18, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(
              '새 게시글 $count개가 도착했어요!',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardView extends ConsumerWidget {
  const _LeaderboardView({required this.week});
  final int week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boardAsync = ref.watch(leaderboardProvider(week));
    return boardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(leaderboardProvider(week)),
        child: rows.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '아직 공개된 랭킹이 없어요.\n프로필에서 "통계 공개"를 켜면 랭킹에 참여해요!',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final s = rows[i];
                  final rank = i + 1;
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileScreen(
                              userId: s.userId, displayName: s.displayName),
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: rank <= 3
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Text('$rank',
                            style: TextStyle(
                                color: rank <= 3
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(s.displayName ?? '익명'),
                      subtitle: Text('연속 ${s.currentStreak}일 · 단식 ${s.fastingCompleted}회'),
                      trailing: Text('${s.avgPercent}%',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.primary)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final post = item.post;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PostDetailScreen(post: post),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileScreen(
                            userId: post.userId,
                            displayName: post.authorName),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          child: Text(
                            post.authorName.characters.first,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(post.authorName,
                            style: theme.textTheme.titleSmall),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(_ago(post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              if (post.isAchievement)
                _AchievementBlock(post: post)
              else if (post.isMealShare && post.mealData != null)
                _MealShareBlock(mealData: post.mealData!, caption: post.content)
              else
                Text(post.content),
              if (post.hasPhoto) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.photoUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        ref.read(feedProvider.notifier).toggleCheer(post.id),
                    icon: Icon(
                      item.cheeredByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: item.cheeredByMe
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                  Text('${item.cheerCount}'),
                  const SizedBox(width: 16),
                  const Icon(Icons.mode_comment_outlined, size: 20),
                  const SizedBox(width: 6),
                  Text('${item.commentCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금';
    if (d.inHours < 1) return '${d.inMinutes}분 전';
    if (d.inDays < 1) return '${d.inHours}시간 전';
    return '${d.inDays}일 전';
  }
}

/// 성과 카드 블록(피드 내).
class _AchievementBlock extends StatelessWidget {
  const _AchievementBlock({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events,
                  color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(post.achievementTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in post.achievementLines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('· $line',
                  style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer)),
            ),
        ],
      ),
    );
  }
}

/// 식단 공유 블록(피드 내).
class _MealShareBlock extends StatelessWidget {
  const _MealShareBlock({required this.mealData, required this.caption});
  final MealShareData mealData;
  final String caption;

  Color _verdictColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (mealData.aiVerdict) {
      case 'fit':
        return cs.primary;
      case 'caution':
        return Colors.orange;
      case 'violation':
        return cs.error;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 끼니 + AI 판정 배지
          Row(
            children: [
              Icon(Icons.restaurant_menu_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(mealData.slotLabel,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
              const Spacer(),
              if (mealData.aiVerdict != null && mealData.aiVerdict!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _verdictColor(context).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _verdictColor(context).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mealData.aiScore != null) ...[
                        Text('${mealData.aiScore}점',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: _verdictColor(context),
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                      ],
                      Text(mealData.verdictLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: _verdictColor(context))),
                    ],
                  ),
                ),
            ],
          ),
          // 사진
          if ((mealData.photoUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                mealData.photoUrl!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          // 인식한 음식
          if ((mealData.aiFoods ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(mealData.aiFoods!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ],
          // 칼로리 + 영양소
          if (mealData.hasNutrition) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _NutriBadge(label: '${mealData.aiCalories} kcal'),
                if (mealData.aiCarbsG != null)
                  _NutriBadge(label: '탄 ${mealData.aiCarbsG}g'),
                if (mealData.aiProteinG != null)
                  _NutriBadge(label: '단 ${mealData.aiProteinG}g'),
                if (mealData.aiFatG != null)
                  _NutriBadge(label: '지 ${mealData.aiFatG}g'),
              ],
            ),
          ],
          // 음식 태그
          if (mealData.foodTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in mealData.foodTags)
                  Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                    labelStyle: theme.textTheme.labelSmall,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
          // 한마디 캡션
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(caption,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _NutriBadge extends StatelessWidget {
  const _NutriBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer)),
    );
  }
}

/// 새 글 작성 시트.
class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({required this.week, required this.authorName});
  final int week;
  final String authorName;

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _content = TextEditingController();
  XFile? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file != null) setState(() => _picked = file);
  }

  Future<void> _post() async {
    if (_content.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final service = ref.read(communityServiceProvider);
    try {
      String? photoUrl;
      if (_picked != null) {
        final bytes = await _picked!.readAsBytes();
        final name = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
        photoUrl = await service.uploadPhoto(bytes, name);
      }
      await service.createPost(
        week: widget.week,
        authorName: widget.authorName,
        content: _content.text.trim(),
        photoUrl: photoUrl,
      );
      await ref.read(feedProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.week}주차 그룹에 글쓰기',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '오늘의 인증, 후기, 응원 한마디를 남겨보세요',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pick,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_picked == null ? '인증샷 추가 (선택)' : '사진 선택됨 ✓'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _post,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('게시'),
          ),
        ],
      ),
    );
  }
}
