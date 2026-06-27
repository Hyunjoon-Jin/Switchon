import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community.dart';
import '../models/public_stat.dart';

/// 커뮤니티 데이터 접근 (게시글·응원·댓글·사진·닉네임·디바이스 토큰).
class CommunityService {
  CommunityService(this._client);
  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  // --- 피드 -------------------------------------------------------------------

  Future<List<FeedItem>> fetchFeed(int week) async {
    final myUid = _uid;
    final posts = await _client
        .from('community_posts')
        .select()
        .eq('group_week', week)
        .order('created_at', ascending: false)
        .limit(50);
    final list = (posts as List)
        .map((e) => CommunityPost.fromMap(e as Map<String, dynamic>))
        .toList();
    if (list.isEmpty) return [];

    final ids = list.map((p) => p.id).toList();
    final cheers = await _client
        .from('community_cheers')
        .select('post_id,user_id')
        .inFilter('post_id', ids);
    final comments = await _client
        .from('community_comments')
        .select('post_id')
        .inFilter('post_id', ids);

    final cheerCount = <String, int>{};
    final mine = <String>{};
    for (final c in cheers as List) {
      final pid = c['post_id'] as String;
      cheerCount[pid] = (cheerCount[pid] ?? 0) + 1;
      if (myUid != null && c['user_id'] == myUid) mine.add(pid);
    }
    final commentCount = <String, int>{};
    for (final c in comments as List) {
      final pid = c['post_id'] as String;
      commentCount[pid] = (commentCount[pid] ?? 0) + 1;
    }

    return [
      for (final p in list)
        FeedItem(
          post: p,
          cheerCount: cheerCount[p.id] ?? 0,
          cheeredByMe: mine.contains(p.id),
          commentCount: commentCount[p.id] ?? 0,
        ),
    ];
  }

  // --- 게시글 -----------------------------------------------------------------

  Future<void> createPost({
    required int week,
    required String authorName,
    required String content,
    String? photoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    await _client.from('community_posts').insert({
      'user_id': uid,
      'author_name': authorName,
      'group_week': week,
      'content': content,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
    });
  }

  Future<void> deletePost(String id) async {
    await _client.from('community_posts').delete().eq('id', id);
  }

  /// 성과 카드 게시글 작성.
  Future<void> createAchievementPost({
    required int week,
    required String authorName,
    required String title,
    required List<String> lines,
    String content = '성과를 공유했어요 🎉',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    await _client.from('community_posts').insert({
      'user_id': uid,
      'author_name': authorName,
      'group_week': week,
      'content': content,
      'kind': 'achievement',
      'achievement': {'title': title, 'lines': lines},
    });
  }

  /// 특정 사용자의 게시글(프로필용).
  Future<List<CommunityPost>> fetchUserPosts(String userId) async {
    final rows = await _client
        .from('community_posts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => CommunityPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // --- 공개 통계 (opt-in) ------------------------------------------------------

  Future<PublicStat?> fetchPublicStats(String userId) async {
    final row = await _client
        .from('public_stats')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return PublicStat.fromMap(row);
  }

  /// 내 공개 통계 upsert (요약 수치 + 공개 여부).
  Future<void> upsertMyPublicStats({
    String? displayName,
    int? currentWeek,
    required double avgCompletion,
    required int fastingCompleted,
    required int currentStreak,
    required bool isPublic,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    await _client.from('public_stats').upsert({
      'user_id': uid,
      'display_name': displayName,
      'current_week': currentWeek,
      'avg_completion': avgCompletion,
      'fasting_completed': fastingCompleted,
      'current_streak': currentStreak,
      'is_public': isPublic,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 같은 주차 그룹 리더보드(공개된 사용자만, 달성률·연속일 순).
  Future<List<PublicStat>> fetchLeaderboard(int week) async {
    final rows = await _client
        .from('public_stats')
        .select()
        .eq('is_public', true)
        .eq('current_week', week)
        .order('avg_completion', ascending: false)
        .order('current_streak', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => PublicStat.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // --- 응원 -------------------------------------------------------------------

  Future<void> toggleCheer(String postId, {required bool currentlyCheered}) async {
    final uid = _uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    if (currentlyCheered) {
      await _client
          .from('community_cheers')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    } else {
      await _client
          .from('community_cheers')
          .insert({'post_id': postId, 'user_id': uid});
    }
  }

  // --- 댓글 -------------------------------------------------------------------

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((e) => CommunityComment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addComment({
    required String postId,
    required String authorName,
    required String content,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    await _client.from('community_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'author_name': authorName,
      'content': content,
    });
  }

  // --- 사진 (공개 버킷) --------------------------------------------------------

  Future<String> uploadPhoto(Uint8List bytes, String fileName) async {
    final uid = _uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    final path = '$uid/$fileName';
    await _client.storage.from('community-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('community-photos').getPublicUrl(path);
  }

  // --- 닉네임 / 디바이스 토큰 ----------------------------------------------------

  Future<void> updateDisplayName(String name) async {
    final uid = _uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    await _client.from('profiles').update({'display_name': name}).eq('id', uid);
  }

  /// 원격 푸시(FCM) 토큰 등록 — Edge Function 이 device_tokens 를 참조해 발송.
  Future<void> upsertDeviceToken(String token, String platform) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('device_tokens').upsert({
      'user_id': uid,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
