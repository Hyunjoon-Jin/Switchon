import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../data/models/community.dart';
import '../../data/models/public_stat.dart';

/// 사용자의 현재 주차 그룹 번호(피드 대상). 시작 전이면 1주차로 폴백.
final feedWeekProvider = Provider<int>((ref) {
  final pos = ref.watch(currentStagePositionProvider);
  return pos?.week ?? 1;
});

/// 같은 주차 그룹 리더보드.
final leaderboardProvider =
    FutureProvider.family<List<PublicStat>, int>((ref, week) {
  ref.watch(authStateProvider);
  return ref.watch(communityServiceProvider).fetchLeaderboard(week);
});

/// 특정 사용자의 공개 통계.
final publicStatProvider =
    FutureProvider.family<PublicStat?, String>((ref, userId) {
  ref.watch(authStateProvider);
  return ref.watch(communityServiceProvider).fetchPublicStats(userId);
});

/// 특정 사용자의 게시글.
final userPostsProvider =
    FutureProvider.family<List<CommunityPost>, String>((ref, userId) {
  ref.watch(authStateProvider);
  return ref.watch(communityServiceProvider).fetchUserPosts(userId);
});

/// 현재 주차 그룹 피드.
final feedProvider =
    AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);

/// 피드 상태 — 항목 목록 + 실시간으로 도착한 새 게시글 수.
class FeedState {
  const FeedState({required this.items, this.newCount = 0});
  final List<FeedItem> items;
  final int newCount; // 사용자가 확인 전 새로 도착한 게시글 수

  FeedState copyWith({List<FeedItem>? items, int? newCount}) => FeedState(
        items: items ?? this.items,
        newCount: newCount ?? this.newCount,
      );
}

class FeedController extends AsyncNotifier<FeedState> {
  RealtimeChannel? _channel;

  @override
  Future<FeedState> build() async {
    ref.watch(authStateProvider);
    final week = ref.watch(feedWeekProvider);
    final service = ref.watch(communityServiceProvider);

    // 기존 채널 정리
    _channel?.unsubscribe();

    // Realtime 구독 — 새 게시글이 오면 newCount 증가
    _channel = service.subscribeToFeed(
      week: week,
      onInsert: _onRealtimeInsert,
    );
    ref.onDispose(() => _channel?.unsubscribe());

    final items = await service.fetchFeed(week);
    return FeedState(items: items);
  }

  void _onRealtimeInsert(CommunityPost post) {
    final current = state.valueOrNull;
    if (current == null) return;
    // 내가 쓴 글은 이미 refresh()로 반영되므로 newCount 를 올리지 않는다.
    final myUid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isMine = post.userId == myUid;

    final newItem = FeedItem(
      post: post,
      cheerCount: 0,
      cheeredByMe: false,
      commentCount: 0,
    );
    // 이미 목록에 있으면 무시 (중복 방지)
    if (current.items.any((f) => f.post.id == post.id)) return;

    state = AsyncData(current.copyWith(
      items: [newItem, ...current.items],
      newCount: isMine ? current.newCount : current.newCount + 1,
    ));
  }

  Future<void> refresh() async {
    final week = ref.read(feedWeekProvider);
    final items =
        await ref.read(communityServiceProvider).fetchFeed(week);
    state = AsyncData(FeedState(items: items));
  }

  /// 새 게시글 알림 배너를 닫을 때 카운트 초기화.
  void clearNewCount() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(newCount: 0));
  }

  /// 응원 토글 — 낙관적 업데이트.
  Future<void> toggleCheer(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final list = current.items;
    final idx = list.indexWhere((f) => f.post.id == postId);
    if (idx < 0) return;
    final item = list[idx];
    final nextCheered = !item.cheeredByMe;
    final optimistic = [...list];
    optimistic[idx] = item.copyWith(
      cheeredByMe: nextCheered,
      cheerCount: item.cheerCount + (nextCheered ? 1 : -1),
    );
    state = AsyncData(current.copyWith(items: optimistic));
    try {
      await ref
          .read(communityServiceProvider)
          .toggleCheer(postId, currentlyCheered: item.cheeredByMe);
    } catch (_) {
      state = AsyncData(current); // 롤백
    }
  }
}
