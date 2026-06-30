/// `daily_logs` 테이블에 대응하는 모델 — 하루치 체크리스트.
///
/// 끼니(아침·점심·간식·저녁) 체크와 고강도 운동만 추적합니다.
/// (물·수면 기록은 스위치온 규칙·식단 중심 개편으로 제거되었습니다.)
class DailyLog {
  const DailyLog({
    required this.logDate,
    this.id,
    this.fastingDone = false,
    this.exerciseDone = false,
    this.missionDone = const [],
  });

  final String? id;
  final DateTime logDate;
  final bool fastingDone;
  final bool exerciseDone;
  final List<String> missionDone; // 체크한 끼니 슬롯/미션 라벨

  /// 끼니 슬롯 키 — 체크 상태는 [missionDone] 에 이 키로 저장됩니다.
  static const List<String> mealSlots = [
    'breakfast', // 아침
    'lunch', // 점심
    'snack', // 간식
    'dinner', // 저녁
  ];

  /// 해당 끼니를 (식단표대로) 챙겼는지 체크 여부.
  bool mealDone(String slot) => missionDone.contains(slot);

  /// 오늘 챙긴 끼니 수(0~4).
  int get mealsDoneCount => mealSlots.where(missionDone.contains).length;

  /// 끼니 4개(아침·점심·간식·저녁) + 고강도 운동 기준 달성률 0.0~1.0
  double get completionRate {
    final done = mealsDoneCount + (exerciseDone ? 1 : 0);
    return done / (mealSlots.length + 1);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  factory DailyLog.empty(DateTime date) => DailyLog(logDate: dateOnly(date));

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'] as String?,
      logDate: DateTime.parse(map['log_date'] as String),
      fastingDone: (map['fasting_done'] as bool?) ?? false,
      exerciseDone: (map['exercise_done'] as bool?) ?? false,
      missionDone: ((map['mission_done'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'log_date': dateOnly(logDate).toIso8601String().split('T').first,
        'fasting_done': fastingDone,
        'exercise_done': exerciseDone,
        'mission_done': missionDone,
        'completion_rate': completionRate,
      };

  DailyLog copyWith({
    bool? fastingDone,
    bool? exerciseDone,
    List<String>? missionDone,
  }) {
    return DailyLog(
      id: id,
      logDate: logDate,
      fastingDone: fastingDone ?? this.fastingDone,
      exerciseDone: exerciseDone ?? this.exerciseDone,
      missionDone: missionDone ?? this.missionDone,
    );
  }
}
