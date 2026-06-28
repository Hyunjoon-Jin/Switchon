/// `fasting_sessions` 테이블 모델 — 단식 타이머 세션.
class FastingSession {
  const FastingSession({
    required this.id,
    required this.startedAt,
    required this.targetHours,
    this.endedAt,
    this.status = 'active',
  });

  final String id;
  final DateTime startedAt;
  final int targetHours; // 14 | 24
  final DateTime? endedAt;
  final String status; // active | completed | canceled

  Duration get targetDuration => Duration(hours: targetHours);
  DateTime get targetEnd => startedAt.add(targetDuration);

  Duration elapsedAt(DateTime now) {
    final d = now.difference(startedAt);
    return d.isNegative ? Duration.zero : d;
  }

  Duration remainingAt(DateTime now) {
    final r = targetEnd.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool reachedGoalAt(DateTime now) => now.isAfter(targetEnd) || now == targetEnd;

  double progressAt(DateTime now) {
    final total = targetDuration.inSeconds;
    if (total == 0) return 0;
    return (elapsedAt(now).inSeconds / total).clamp(0.0, 1.0);
  }

  factory FastingSession.fromMap(Map<String, dynamic> map) {
    return FastingSession(
      id: map['id'] as String,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      targetHours: map['target_hours'] as int,
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String).toLocal(),
      status: (map['status'] as String?) ?? 'active',
    );
  }
}
