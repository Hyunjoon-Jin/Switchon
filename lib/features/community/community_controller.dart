import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/community.dart';

/// 사용자의 현재 주차 그룹 번호(피드 대상). 시작 전이면 1주차로 폴백.
final feedWeekProvider = Provider<int>((ref) {
  final pos = ref.watch(currentStagePositionProvider);
  return pos?.week ?? 1;
});

/// 현재 주차 그룹 피드.
final feedProvider =
    AsyncNotifierProvider<FeedController, List<FeedItem>>(FeedController.new);

class FeedController extends AsyncNotifier<List<FeedItem>> {
  @override
  Future<List<FeedItem>> build() {
    ref.watch(authStateProvider);
    final week = ref.watch(feedWeekProvider);
    return ref.watch(communityServiceProvider).fetchFeed(week);
  }

  Future<void> refresh() async {
    final week = ref.read(feedWeekProvider);
    state = await AsyncValue.guard(
      () => ref.read(communityServiceProvider).fetchFeed(week),
    );
  }

  /// 응원 토글 — 낙관적 업데이트.
  Future<void> toggleCheer(String postId) async {
    final list = state.valueOrNull;
    if (list == null) return;
    final idx = list.indexWhere((f) => f.post.id == postId);
    if (idx < 0) return;
    final item = list[idx];
    final nextCheered = !item.cheeredByMe;
    final optimistic = [...list];
    optimistic[idx] = item.copyWith(
      cheeredByMe: nextCheered,
      cheerCount: item.cheerCount + (nextCheered ? 1 : -1),
    );
    state = AsyncData(optimistic);
    try {
      await ref
          .read(communityServiceProvider)
          .toggleCheer(postId, currentlyCheered: item.cheeredByMe);
    } catch (_) {
      state = AsyncData(list); // 롤백
    }
  }
}
