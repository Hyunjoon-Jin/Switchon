import 'package:flutter_test/flutter_test.dart';
import 'package:switchon/data/models/daily_log.dart';

void main() {
  final date = DateTime(2026, 6, 26);

  test('빈 로그의 달성률은 0', () {
    expect(DailyLog.empty(date).completionRate, 0.0);
  });

  test('끼니 1개 체크 시 1/5 달성', () {
    final log = DailyLog(logDate: date, missionDone: const ['breakfast']);
    expect(log.mealDone('breakfast'), true);
    expect(log.mealsDoneCount, 1);
    expect(log.completionRate, closeTo(0.2, 1e-9));
  });

  test('끼니 4개 + 운동 모두 충족 시 100%', () {
    final log = DailyLog(
      logDate: date,
      exerciseDone: true,
      missionDone: const ['breakfast', 'lunch', 'snack', 'dinner'],
    );
    expect(log.mealsDoneCount, 4);
    expect(log.completionRate, 1.0);
  });
}
