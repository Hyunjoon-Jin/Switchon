import '../../data/models/daily_log.dart';
import '../../data/models/fasting_session.dart';
import '../../data/models/meal_log.dart';

/// 통계 대시보드용 집계 결과.
class StatsSummary {
  const StatsSummary({
    required this.trend,
    required this.daysLogged,
    required this.avgCompletion,
    required this.waterDays,
    required this.sleepDays,
    required this.fastingDays,
    required this.exerciseDays,
    required this.totalShakes,
    required this.completedFastings,
    required this.violations,
  });

  /// 최근 windowDays 일의 일자별 달성률(빈 날 포함, 시간순).
  final List<DayBar> trend;
  final int daysLogged;
  final double avgCompletion; // 기록한 날 기준 평균 0.0~1.0

  // 윈도우 내 항목별 달성 일수
  final int waterDays;
  final int sleepDays;
  final int fastingDays;
  final int exerciseDays;

  // 누적(전체 기간)
  final int totalShakes;
  final int completedFastings;
  final int violations;

  bool get isEmpty => daysLogged == 0 && totalShakes == 0;
}

class DayBar {
  const DayBar({required this.date, required this.rate, required this.logged});
  final DateTime date;
  final double rate; // 0.0~1.0
  final bool logged;
}

/// 원자료 → 통계 요약. 순수 함수(테스트 용이).
StatsSummary computeStats({
  required List<DailyLog> recentLogs,
  required List<MealLog> meals,
  required List<FastingSession> fastings,
  required DateTime today,
  int windowDays = 14,
}) {
  final base = DateTime(today.year, today.month, today.day);

  // 날짜 → 로그 매핑
  final byDate = <String, DailyLog>{};
  for (final l in recentLogs) {
    byDate[_key(l.logDate)] = l;
  }

  final trend = <DayBar>[];
  var sumRate = 0.0;
  var logged = 0;
  var waterDays = 0, sleepDays = 0, fastingDays = 0, exerciseDays = 0;

  for (var i = windowDays - 1; i >= 0; i--) {
    final date = base.subtract(Duration(days: i));
    final log = byDate[_key(date)];
    if (log != null) {
      trend.add(DayBar(date: date, rate: log.completionRate, logged: true));
      sumRate += log.completionRate;
      logged++;
      if (log.waterDone) waterDays++;
      if (log.sleepDone) sleepDays++;
      if (log.fastingDone) fastingDays++;
      if (log.exerciseDone) exerciseDays++;
    } else {
      trend.add(DayBar(date: date, rate: 0, logged: false));
    }
  }

  final totalShakes = meals
      .where((m) => m.isShake)
      .fold<int>(0, (sum, m) => sum + m.shakeCount);
  final violations = meals.where((m) => m.ruleViolation == true).length;
  final completedFastings =
      fastings.where((f) => f.status == 'completed').length;

  return StatsSummary(
    trend: trend,
    daysLogged: logged,
    avgCompletion: logged == 0 ? 0 : sumRate / logged,
    waterDays: waterDays,
    sleepDays: sleepDays,
    fastingDays: fastingDays,
    exerciseDays: exerciseDays,
    totalShakes: totalShakes,
    completedFastings: completedFastings,
    violations: violations,
  );
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
