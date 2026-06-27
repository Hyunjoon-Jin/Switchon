/// `daily_logs` 테이블에 대응하는 모델 — 하루치 체크리스트.
class DailyLog {
  const DailyLog({
    required this.logDate,
    this.id,
    this.waterMl = 0,
    this.sleepHours,
    this.sleepStartMinutes,
    this.sleepEndMinutes,
    this.fastingDone = false,
    this.exerciseDone = false,
    this.missionDone = const [],
  });

  final String? id;
  final DateTime logDate;
  final int waterMl;
  final double? sleepHours;
  final int? sleepStartMinutes; // 잠든 시각: 자정 기준 분(0~1439)
  final int? sleepEndMinutes; // 일어난 시각
  final bool fastingDone;
  final bool exerciseDone;
  final List<String> missionDone; // 체크한 미션 라벨

  /// 목표값
  static const int waterTargetMl = 2000;
  static const double sleepTargetHours = 6;

  bool get waterDone => waterMl >= waterTargetMl;
  bool get sleepDone => (sleepHours ?? 0) >= sleepTargetHours;
  bool get hasSleepTimes =>
      sleepStartMinutes != null && sleepEndMinutes != null;

  /// 잠든 시각·일어난 시각(자정 넘김 포함)으로 수면 시간(시) 계산.
  static double durationHours(int startMin, int endMin) {
    var diff = endMin - startMin;
    if (diff <= 0) diff += 24 * 60; // 자정을 넘긴 경우
    return diff / 60.0;
  }

  /// 4개 항목(물·수면·단식·운동) 기준 달성률 0.0~1.0
  double get completionRate {
    final done = [waterDone, sleepDone, fastingDone, exerciseDone]
        .where((e) => e)
        .length;
    return done / 4;
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  factory DailyLog.empty(DateTime date) => DailyLog(logDate: dateOnly(date));

  static int? _parseTime(Object? v) {
    if (v == null) return null;
    final parts = (v as String).split(':'); // "HH:MM:SS"
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String? _fmtTime(int? minutes) {
    if (minutes == null) return null;
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'] as String?,
      logDate: DateTime.parse(map['log_date'] as String),
      waterMl: (map['water_ml'] as int?) ?? 0,
      sleepHours: (map['sleep_hours'] as num?)?.toDouble(),
      sleepStartMinutes: _parseTime(map['sleep_start']),
      sleepEndMinutes: _parseTime(map['sleep_end']),
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
        'water_ml': waterMl,
        'water_done': waterDone,
        'sleep_hours': sleepHours,
        'sleep_start': _fmtTime(sleepStartMinutes),
        'sleep_end': _fmtTime(sleepEndMinutes),
        'fasting_done': fastingDone,
        'exercise_done': exerciseDone,
        'mission_done': missionDone,
        'completion_rate': completionRate,
      };

  DailyLog copyWith({
    int? waterMl,
    double? sleepHours,
    int? sleepStartMinutes,
    int? sleepEndMinutes,
    bool? fastingDone,
    bool? exerciseDone,
    List<String>? missionDone,
  }) {
    return DailyLog(
      id: id,
      logDate: logDate,
      waterMl: waterMl ?? this.waterMl,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepStartMinutes: sleepStartMinutes ?? this.sleepStartMinutes,
      sleepEndMinutes: sleepEndMinutes ?? this.sleepEndMinutes,
      fastingDone: fastingDone ?? this.fastingDone,
      exerciseDone: exerciseDone ?? this.exerciseDone,
      missionDone: missionDone ?? this.missionDone,
    );
  }
}
