/// 커뮤니티 게시글.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.groupWeek,
    required this.content,
    required this.createdAt,
    this.photoUrl,
  });

  final String id;
  final String userId;
  final String authorName;
  final int groupWeek;
  final String content;
  final DateTime createdAt;
  final String? photoUrl;

  bool get hasPhoto => (photoUrl ?? '').isNotEmpty;

  factory CommunityPost.fromMap(Map<String, dynamic> m) {
    return CommunityPost(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      authorName: m['author_name'] as String,
      groupWeek: m['group_week'] as int,
      content: m['content'] as String,
      photoUrl: m['photo_url'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

/// 피드 항목 = 게시글 + 응원/댓글 집계 + 내 응원 여부.
class FeedItem {
  const FeedItem({
    required this.post,
    required this.cheerCount,
    required this.cheeredByMe,
    required this.commentCount,
  });

  final CommunityPost post;
  final int cheerCount;
  final bool cheeredByMe;
  final int commentCount;

  FeedItem copyWith({int? cheerCount, bool? cheeredByMe, int? commentCount}) {
    return FeedItem(
      post: post,
      cheerCount: cheerCount ?? this.cheerCount,
      cheeredByMe: cheeredByMe ?? this.cheeredByMe,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String userId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  factory CommunityComment.fromMap(Map<String, dynamic> m) {
    return CommunityComment(
      id: m['id'] as String,
      postId: m['post_id'] as String,
      userId: m['user_id'] as String,
      authorName: m['author_name'] as String,
      content: m['content'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}
