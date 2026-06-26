import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'stats.dart';

const int kStatsWindowDays = 14;

/// 통계 요약 — 원자료를 모아 순수 함수 computeStats 로 집계.
final statsProvider = FutureProvider<StatsSummary>((ref) async {
  ref.watch(authStateProvider);
  final service = ref.watch(supabaseServiceProvider);

  final logs = await service.fetchRecentDailyLogs(kStatsWindowDays);
  final meals = await service.fetchAllMeals();
  final fastings = await service.fetchAllFastings();

  return computeStats(
    recentLogs: logs,
    meals: meals,
    fastings: fastings,
    today: DateTime.now(),
    windowDays: kStatsWindowDays,
  );
});
