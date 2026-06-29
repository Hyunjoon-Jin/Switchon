/// 식단 공유 게시글에 첨부되는 식사 정보.
class MealShareData {
  const MealShareData({
    required this.slot,
    required this.slotLabel,
    this.foodTags = const [],
    this.aiVerdict,
    this.aiScore,
    this.aiCalories,
    this.aiCarbsG,
    this.aiProteinG,
    this.aiFatG,
    this.aiFoods,
    this.memo,
    this.photoUrl,
  });

  final String slot;
  final String slotLabel;
  final List<String> foodTags;
  final String? aiVerdict; // fit | caution | violation
  final int? aiScore;
  final int? aiCalories;
  final int? aiCarbsG;
  final int? aiProteinG;
  final int? aiFatG;
  final String? aiFoods;
  final String? memo;
  final String? photoUrl; // community-photos 공개 URL

  bool get hasNutrition => aiCalories != null;

  String get verdictLabel {
    switch (aiVerdict) {
      case 'fit':
        return '적합';
      case 'caution':
        return '주의';
      case 'violation':
        return '단계 제한';
      default:
        return '';
    }
  }

  factory MealShareData.fromMap(Map<String, dynamic> m) => MealShareData(
        slot: (m['slot'] as String?) ?? '',
        slotLabel: (m['slotLabel'] as String?) ?? '식사',
        foodTags: ((m['foodTags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        aiVerdict: m['aiVerdict'] as String?,
        aiScore: (m['aiScore'] as num?)?.toInt(),
        aiCalories: (m['aiCalories'] as num?)?.toInt(),
        aiCarbsG: (m['aiCarbsG'] as num?)?.toInt(),
        aiProteinG: (m['aiProteinG'] as num?)?.toInt(),
        aiFatG: (m['aiFatG'] as num?)?.toInt(),
        aiFoods: m['aiFoods'] as String?,
        memo: m['memo'] as String?,
        photoUrl: m['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'slot': slot,
        'slotLabel': slotLabel,
        'foodTags': foodTags,
        if (aiVerdict != null) 'aiVerdict': aiVerdict,
        if (aiScore != null) 'aiScore': aiScore,
        if (aiCalories != null) 'aiCalories': aiCalories,
        if (aiCarbsG != null) 'aiCarbsG': aiCarbsG,
        if (aiProteinG != null) 'aiProteinG': aiProteinG,
        if (aiFatG != null) 'aiFatG': aiFatG,
        if (aiFoods != null) 'aiFoods': aiFoods,
        if (memo != null) 'memo': memo,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
}

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
    this.kind = 'normal',
    this.achievement,
    this.mealData,
  });

  final String id;
  final String userId;
  final String authorName;
  final int groupWeek;
  final String content;
  final DateTime createdAt;
  final String? photoUrl;
  final String kind; // normal | achievement | meal_share
  final Map<String, dynamic>? achievement; // {title, lines:[...]}
  final MealShareData? mealData; // kind=meal_share 일 때 식사 정보

  bool get hasPhoto => (photoUrl ?? '').isNotEmpty;
  bool get isAchievement => kind == 'achievement';
  bool get isMealShare => kind == 'meal_share';

  String get achievementTitle =>
      (achievement?['title'] as String?) ?? '성과 달성!';
  List<String> get achievementLines =>
      ((achievement?['lines'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  factory CommunityPost.fromMap(Map<String, dynamic> m) {
    final mealRaw = m['meal_data'];
    return CommunityPost(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      authorName: m['author_name'] as String,
      groupWeek: m['group_week'] as int,
      content: m['content'] as String,
      photoUrl: m['photo_url'] as String?,
      kind: (m['kind'] as String?) ?? 'normal',
      achievement: m['achievement'] as Map<String, dynamic>?,
      mealData: mealRaw is Map<String, dynamic>
          ? MealShareData.fromMap(mealRaw)
          : null,
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
