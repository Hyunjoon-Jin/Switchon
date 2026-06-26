import 'package:flutter_test/flutter_test.dart';
import 'package:switchon/data/models/daily_log.dart';

void main() {
  final date = DateTime(2026, 6, 26);

  test('빈 로그의 달성률은 0', () {
    expect(DailyLog.empty(date).completionRate, 0.0);
  });

  test('물 2000ml 이상이면 물 항목 달성', () {
    final log = DailyLog(logDate: date, waterMl: 2000);
    expect(log.waterDone, true);
    expect(log.completionRate, 0.25);
  });

  test('네 항목 모두 충족 시 100%', () {
    final log = DailyLog(
      logDate: date,
      waterMl: 2100,
      sleepHours: 7,
      fastingDone: true,
      exerciseDone: true,
    );
    expect(log.completionRate, 1.0);
  });

  test('수면 6시간 미만은 미달성', () {
    final log = DailyLog(logDate: date, sleepHours: 5.5);
    expect(log.sleepDone, false);
  });
}
