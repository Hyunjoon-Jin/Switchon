import '../../core/program/switchon_program.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/meal_log.dart';

/// 하루 식단 달력 칸의 평가 결과 (색상).
enum DayResult {
  none, // 예정/기록 전 — 회색
  good, // 스위치온 규칙 지킴 — 초록
  ok, // 보통 — 노랑
  bad, // 망함 — 빨강
}

/// 식단 달력의 하루(주차·일차) 칸.
class CalendarDay {
  const CalendarDay({
    required this.week,
    required this.day,
    required this.date,
    required this.result,
    required this.meals,
    required this.isFasting,
  });

  final int week; // 1..4
  final int day; // 1..7
  final DateTime date;
  final DayResult result;

  /// 슬롯 키 → 표시 문자열(먹은 음식이 있으면 그 내용, 없으면 식단표 안내).
  final Map<String, String> meals;
  final bool isFasting;
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 시작일·일일 로그·식사 기록으로 4주(28일) 식단 달력을 만든다. 순수 함수.
List<CalendarDay> computeMealCalendar({
  required DateTime startDate,
  required List<DailyLog> logs,
  required List<MealLog> meals,
  required DateTime today,
}) {
  final base = DateTime(startDate.year, startDate.month, startDate.day);
  final today0 = DateTime(today.year, today.month, today.day);

  final logByDate = <String, DailyLog>{
    for (final l in logs) _key(l.logDate): l,
  };
  final mealsByDate = <String, List<MealLog>>{};
  for (final m in meals) {
    (mealsByDate[_key(m.loggedAt)] ??= []).add(m);
  }

  final out = <CalendarDay>[];
  for (var week = 1; week <= SwitchOnProgram.totalWeeks; week++) {
    for (var day = 1; day <= SwitchOnProgram.daysPerWeek; day++) {
      final idx = (week - 1) * SwitchOnProgram.daysPerWeek + (day - 1);
      final date = base.add(Duration(days: idx));
      final k = _key(date);
      final log = logByDate[k];
      final dayMeals = SwitchOnProgram.dayMeals(week, day);
      final dayMealLogs = mealsByDate[k] ?? const <MealLog>[];

      // 슬롯별 표시 문자열: 먹은 음식(memo) 우선, 없으면 식단표 안내.
      final mealMap = <String, String>{};
      for (final slot in DailyLog.mealSlots) {
        final memos = dayMealLogs
            .where((m) => m.mealSlot == slot && (m.memo ?? '').isNotEmpty)
            .map((m) => m.memo!)
            .toList();
        mealMap[slot] =
            memos.isNotEmpty ? memos.join(', ') : dayMeals.forSlot(slot);
      }

      final doneCount = log?.mealsDoneCount ?? 0;
      final violation = dayMealLogs.any((m) => m.ruleViolation == true);

      final DayResult result;
      if (date.isAfter(today0)) {
        result = DayResult.none; // 아직 오지 않은 날
      } else if (k == _key(today0)) {
        // 오늘: 아직 기록 전이면 회색, 진행 중이면 노랑, 다 지키면 초록.
        if (doneCount == 0 && dayMealLogs.isEmpty) {
          result = DayResult.none;
        } else if (doneCount == DailyLog.mealSlots.length && !violation) {
          result = DayResult.good;
        } else {
          result = DayResult.ok;
        }
      } else {
        // 지난 날: 4끼 모두 + 위반 없음=초록, 1~3끼=노랑, 0끼=빨강.
        if (doneCount == DailyLog.mealSlots.length && !violation) {
          result = DayResult.good;
        } else if (doneCount == 0) {
          result = DayResult.bad;
        } else {
          result = DayResult.ok;
        }
      }

      out.add(CalendarDay(
        week: week,
        day: day,
        date: date,
        result: result,
        meals: mealMap,
        isFasting: dayMeals.isFasting,
      ));
    }
  }
  return out;
}
