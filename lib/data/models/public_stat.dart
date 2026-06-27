/// `public_stats` 테이블 모델 — opt-in 공개 통계 요약.
class PublicStat {
  const PublicStat({
    required this.userId,
    this.displayName,
    this.currentWeek,
    this.avgCompletion = 0,
    this.fastingCompleted = 0,
    this.currentStreak = 0,
    this.isPublic = false,
  });

  final String userId;
  final String? displayName;
  final int? currentWeek;
  final double avgCompletion; // 0.0~1.0
  final int fastingCompleted;
  final int currentStreak;
  final bool isPublic;

  int get avgPercent => (avgCompletion * 100).round();

  factory PublicStat.fromMap(Map<String, dynamic> m) {
    return PublicStat(
      userId: m['user_id'] as String,
      displayName: m['display_name'] as String?,
      currentWeek: m['current_week'] as int?,
      avgCompletion: (m['avg_completion'] as num?)?.toDouble() ?? 0,
      fastingCompleted: (m['fasting_completed'] as int?) ?? 0,
      currentStreak: (m['current_streak'] as int?) ?? 0,
      isPublic: (m['is_public'] as bool?) ?? false,
    );
  }
}
