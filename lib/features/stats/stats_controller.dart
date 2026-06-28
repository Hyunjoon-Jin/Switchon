import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'meal_stats.dart';
import 'stats.dart';

const int kStatsWindowDays = 14;

/// 통계 기간(일). 토글로 7 / 14 / 28 중 선택.
final statsPeriodProvider = StateProvider<int>((_) => kStatsWindowDays);

/// 통계 요약 — 원자료를 모아 순수 함수 computeStats 로 집계.
final statsProvider = FutureProvider<StatsSummary>((ref) async {
  ref.watch(authStateProvider);
  final window = ref.watch(statsPeriodProvider);
  final service = ref.watch(supabaseServiceProvider);

  final logs = await service.fetchRecentDailyLogs(window);
  final meals = await service.fetchAllMeals();
  final fastings = await service.fetchAllFastings();

  return computeStats(
    recentLogs: logs,
    meals: meals,
    fastings: fastings,
    today: DateTime.now(),
    windowDays: window,
  );
});

/// 식사·영양 통계 — 선택 기간 기준.
final mealStatsProvider = FutureProvider<MealStats>((ref) async {
  ref.watch(authStateProvider);
  final window = ref.watch(statsPeriodProvider);
  final meals = await ref.watch(supabaseServiceProvider).fetchAllMeals();
  return computeMealStats(
    meals: meals,
    today: DateTime.now(),
    windowDays: window,
  );
});
