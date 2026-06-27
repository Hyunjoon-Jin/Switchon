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

  group('수면 시각 → 시간 계산', () {
    test('같은 날 (07:00 - 06:00 안 넘김 아님)', () {
      // 23:30 잠들어 07:00 기상 → 7.5시간 (자정 넘김)
      expect(DailyLog.durationHours(23 * 60 + 30, 7 * 60), 7.5);
    });
    test('자정 안 넘김 (01:00 → 08:30 = 7.5h)', () {
      expect(DailyLog.durationHours(60, 8 * 60 + 30), 7.5);
    });
    test('자정 정각 넘김 (22:00 → 06:00 = 8h)', () {
      expect(DailyLog.durationHours(22 * 60, 6 * 60), 8.0);
    });
    test('같은 시각이면 24시간으로 간주(경계)', () {
      expect(DailyLog.durationHours(23 * 60, 23 * 60), 24.0);
    });
  });
}
