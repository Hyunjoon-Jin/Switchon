import 'switchon_program.dart';

/// 현재 단계 위치 (주차/일차/단계 규칙).
class StagePosition {
  const StagePosition({
    required this.week,
    required this.day,
    required this.programDay,
    required this.totalDays,
    required this.isPaused,
    required this.isCompleted,
    required this.stage,
  });

  final int week; // 1..4
  final int day; // 1..7
  final int programDay; // 1..28 (전체 일차)
  final int totalDays;
  final bool isPaused;
  final bool isCompleted;
  final StageRule stage;

  double get progress => (programDay / totalDays).clamp(0.0, 1.0);
}

/// 시작일 + 일시정지 상태로부터 현재 단계를 계산하는 순수 함수 엔진.
///
/// 핵심: 재개 시 start_date 가 멈춰 있던 기간만큼 뒤로 밀려 있으므로,
/// 활성 상태에서는 항상 `경과일 = 오늘 - 시작일`. 일시정지 중에는
/// 멈춘 날(paused_at)에 위치를 고정해 일차가 더 진행되지 않습니다.
class StageEngine {
  StageEngine._();

  static const int totalDays = SwitchOnProgram.totalWeeks * 7; // 28

  static StagePosition compute({
    required DateTime startDate,
    required String status,
    DateTime? pausedAt,
    required DateTime today,
  }) {
    final start = _dateOnly(startDate);
    final isPaused = status == 'paused';

    // 위치 계산 기준일: 일시정지 중이면 멈춘 날, 아니면 오늘.
    final anchor = isPaused ? _dateOnly(pausedAt ?? today) : _dateOnly(today);

    var elapsed = anchor.difference(start).inDays;
    if (elapsed < 0) elapsed = 0;

    final programDay = elapsed + 1;
    final completedByStatus = status == 'completed';
    final completedByDuration = programDay > totalDays;
    final isCompleted = completedByStatus || completedByDuration;

    // 완료 후에는 마지막 일차에 고정해 표시.
    final boundedElapsed = elapsed >= totalDays ? totalDays - 1 : elapsed;
    final week = (boundedElapsed ~/ 7 + 1).clamp(1, SwitchOnProgram.totalWeeks);
    final dayInWeek = boundedElapsed % 7 + 1;

    return StagePosition(
      week: week,
      day: dayInWeek,
      programDay: programDay.clamp(1, totalDays),
      totalDays: totalDays,
      isPaused: isPaused,
      isCompleted: isCompleted,
      stage: SwitchOnProgram.stageFor(week, dayInWeek),
    );
  }

  /// 재개 시 새 시작일: 멈춰 있던 일수만큼 뒤로 민다.
  static DateTime resumedStartDate({
    required DateTime startDate,
    required DateTime pausedAt,
    required DateTime today,
  }) {
    final pausedDays = _dateOnly(today).difference(_dateOnly(pausedAt)).inDays;
    final shift = pausedDays < 0 ? 0 : pausedDays;
    return _dateOnly(startDate).add(Duration(days: shift));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
