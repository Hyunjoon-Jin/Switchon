import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/community.dart';
import 'community_controller.dart';
import 'nickname.dart';

/// 게시글 상세 + 댓글.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final CommunityPost post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _comment = TextEditingController();
  List<CommunityComment>? _comments;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ref
          .read(communityServiceProvider)
          .fetchComments(widget.post.id);
      if (mounted) setState(() => _comments = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    final name = await ensureNickname(context, ref);
    if (name == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityServiceProvider).addComment(
            postId: widget.post.id,
            authorName: name,
            content: text,
          );
      _comment.clear();
      await _load();
      // 피드의 댓글 수 갱신
      await ref.read(feedProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 작성에 실패했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.post;
    final comments = _comments;

    return Scaffold(
      appBar: AppBar(title: const Text('게시글')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      child: Text(post.authorName.characters.first),
                    ),
                    const SizedBox(width: 10),
                    Text(post.authorName, style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                Text(post.content, style: theme.textTheme.bodyLarge),
                if (post.hasPhoto) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.photoUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const Divider(height: 32),
                Text('댓글', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error))
                else if (comments == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('첫 댓글로 응원을 남겨보세요.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  )
                else
                  for (final c in comments) _CommentTile(comment: c),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _comment,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: '응원 댓글 달기',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(comment.authorName.characters.first,
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.authorName, style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(comment.content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
