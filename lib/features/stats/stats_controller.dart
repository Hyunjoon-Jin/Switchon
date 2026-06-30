import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'meal_calendar.dart';
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

/// 1~4주차 식단 달력 — 시작일부터 28일을 주차·일차로 펼쳐 색으로 평가.
final mealCalendarProvider = FutureProvider<List<CalendarDay>>((ref) async {
  ref.watch(authStateProvider);
  final service = ref.watch(supabaseServiceProvider);
  final profile = await ref.watch(profileProvider.future);
  final today = DateTime.now();
  final start = profile?.startDate ?? today;

  // 시작일부터 오늘까지(최소 28일) 일일 로그를 확보.
  final since = DateTime(start.year, start.month, start.day);
  final elapsed =
      DateTime(today.year, today.month, today.day).difference(since).inDays + 1;
  final window = elapsed < 28 ? 28 : elapsed;

  final logs = await service.fetchRecentDailyLogs(window);
  final meals = await service.fetchAllMeals();

  return computeMealCalendar(
    startDate: start,
    logs: logs,
    meals: meals,
    today: today,
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
