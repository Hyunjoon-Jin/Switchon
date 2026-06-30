import 'package:flutter_test/flutter_test.dart';
import 'package:switchon/data/models/daily_log.dart';
import 'package:switchon/data/models/fasting_session.dart';
import 'package:switchon/data/models/meal_log.dart';
import 'package:switchon/features/stats/stats.dart';

void main() {
  final today = DateTime(2026, 6, 26);

  DailyLog log(DateTime d,
          {int water = 0,
          double? sleep,
          bool fast = false,
          bool ex = false,
          List<String> meals = const []}) =>
      DailyLog(
        logDate: d,
        waterMl: water,
        sleepHours: sleep,
        fastingDone: fast,
        exerciseDone: ex,
        missionDone: meals,
      );

  test('빈 입력은 isEmpty', () {
    final s = computeStats(
      recentLogs: [],
      meals: [],
      fastings: [],
      today: today,
    );
    expect(s.isEmpty, true);
    expect(s.trend.length, 14);
    expect(s.avgCompletion, 0);
  });

  test('추이는 윈도우 길이만큼, 빈 날은 logged=false', () {
    final s = computeStats(
      recentLogs: [
        log(today,
            ex: true,
            meals: const ['breakfast', 'lunch', 'snack', 'dinner'])
      ],
      meals: [],
      fastings: [],
      today: today,
      windowDays: 7,
    );
    expect(s.trend.length, 7);
    expect(s.trend.last.date, today);
    expect(s.trend.last.logged, true);
    expect(s.trend.last.rate, 1.0);
    expect(s.trend.first.logged, false);
    expect(s.daysLogged, 1);
  });

  test('항목별 달성 일수 집계', () {
    final s = computeStats(
      recentLogs: [
        log(today, water: 2000), // 물만
        log(today.subtract(const Duration(days: 1)), sleep: 8, fast: true),
      ],
      meals: [],
      fastings: [],
      today: today,
    );
    expect(s.waterDays, 1);
    expect(s.sleepDays, 1);
    expect(s.fastingDays, 1);
    expect(s.exerciseDays, 0);
  });

  test('누적: 셰이크 합·단식 완료·위반', () {
    final s = computeStats(
      recentLogs: [],
      meals: [
        MealLog(id: '1', loggedAt: today, type: 'shake', shakeCount: 1),
        MealLog(id: '2', loggedAt: today, type: 'shake', shakeCount: 1),
        MealLog(id: '3', loggedAt: today, type: 'meal', ruleViolation: true),
        MealLog(id: '4', loggedAt: today, type: 'meal', ruleViolation: false),
      ],
      fastings: [
        FastingSession(
            id: 'f1', startedAt: today, targetHours: 14, status: 'completed'),
        FastingSession(
            id: 'f2', startedAt: today, targetHours: 24, status: 'canceled'),
      ],
      today: today,
    );
    expect(s.totalShakes, 2);
    expect(s.violations, 1);
    expect(s.completedFastings, 1);
  });
}
