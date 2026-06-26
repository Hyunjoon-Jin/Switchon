/// `daily_logs` 테이블에 대응하는 모델 — 하루치 체크리스트.
class DailyLog {
  const DailyLog({
    required this.logDate,
    this.id,
    this.waterMl = 0,
    this.sleepHours,
    this.fastingDone = false,
    this.exerciseDone = false,
  });

  final String? id;
  final DateTime logDate;
  final int waterMl;
  final double? sleepHours;
  final bool fastingDone;
  final bool exerciseDone;

  /// 목표값
  static const int waterTargetMl = 2000;
  static const double sleepTargetHours = 6;

  bool get waterDone => waterMl >= waterTargetMl;
  bool get sleepDone => (sleepHours ?? 0) >= sleepTargetHours;

  /// 4개 항목(물·수면·단식·운동) 기준 달성률 0.0~1.0
  double get completionRate {
    final done = [waterDone, sleepDone, fastingDone, exerciseDone]
        .where((e) => e)
        .length;
    return done / 4;
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  factory DailyLog.empty(DateTime date) => DailyLog(logDate: dateOnly(date));

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'] as String?,
      logDate: DateTime.parse(map['log_date'] as String),
      waterMl: (map['water_ml'] as int?) ?? 0,
      sleepHours: (map['sleep_hours'] as num?)?.toDouble(),
      fastingDone: (map['fasting_done'] as bool?) ?? false,
      exerciseDone: (map['exercise_done'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'log_date': dateOnly(logDate).toIso8601String().split('T').first,
        'water_ml': waterMl,
        'water_done': waterDone,
        'sleep_hours': sleepHours,
        'fasting_done': fastingDone,
        'exercise_done': exerciseDone,
        'completion_rate': completionRate,
      };

  DailyLog copyWith({
    int? waterMl,
    double? sleepHours,
    bool? fastingDone,
    bool? exerciseDone,
  }) {
    return DailyLog(
      id: id,
      logDate: logDate,
      waterMl: waterMl ?? this.waterMl,
      sleepHours: sleepHours ?? this.sleepHours,
      fastingDone: fastingDone ?? this.fastingDone,
      exerciseDone: exerciseDone ?? this.exerciseDone,
    );
  }
}
