import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../data/models/community.dart';
import 'community_controller.dart';
import 'nickname.dart';
import 'post_detail_screen.dart';

/// 커뮤니티 — 같은 주차 사용자들의 피드(인증샷·후기·응원).
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(feedWeekProvider);
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: Text('$week주차 그룹')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context, ref, week),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.read(feedProvider.notifier).refresh(),
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
      ),
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref, int week) async {
    final name = await ensureNickname(context, ref);
    if (name == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeSheet(week: week, authorName: name),
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
                  const Spacer(),
                  Text(_ago(post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
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
