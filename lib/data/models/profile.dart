/// `profiles` 테이블에 대응하는 모델.
class Profile {
  const Profile({
    required this.id,
    this.startDate,
    this.currentWeek = 1,
    this.currentDay = 1,
    this.status = 'active',
    this.pausedAt,
    this.goal,
    this.displayName,
    this.trackWeight = false,
    this.birthYear,
    this.ageVerified = false,
    this.safetyAcknowledgedAt,
    this.onboardingCompletedAt,
  });

  final String id;
  final DateTime? startDate;
  final int currentWeek;
  final int currentDay;
  final String status; // active | paused | completed
  final DateTime? pausedAt;
  final String? goal;
  final String? displayName;
  final bool trackWeight;
  final int? birthYear;
  final bool ageVerified;
  final DateTime? safetyAcknowledgedAt;
  final DateTime? onboardingCompletedAt;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;
  bool get hasAcknowledgedSafety => safetyAcknowledgedAt != null;

  factory Profile.fromMap(Map<String, dynamic> map) {
    DateTime? parseTs(Object? v) =>
        v == null ? null : DateTime.parse(v as String);
    return Profile(
      id: map['id'] as String,
      startDate: map['start_date'] == null
          ? null
          : DateTime.parse(map['start_date'] as String),
      currentWeek: (map['current_week'] as int?) ?? 1,
      currentDay: (map['current_day'] as int?) ?? 1,
      status: (map['status'] as String?) ?? 'active',
      pausedAt: map['paused_at'] == null
          ? null
          : DateTime.parse(map['paused_at'] as String),
      goal: map['goal'] as String?,
      displayName: map['display_name'] as String?,
      trackWeight: (map['track_weight'] as bool?) ?? false,
      birthYear: map['birth_year'] as int?,
      ageVerified: (map['age_verified'] as bool?) ?? false,
      safetyAcknowledgedAt: parseTs(map['safety_acknowledged_at']),
      onboardingCompletedAt: parseTs(map['onboarding_completed_at']),
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        if (startDate != null)
          'start_date': startDate!.toIso8601String().split('T').first,
        'current_week': currentWeek,
        'current_day': currentDay,
        'status': status,
        'paused_at': pausedAt == null
            ? null
            : pausedAt!.toIso8601String().split('T').first,
        'goal': goal,
        'display_name': displayName,
        'track_weight': trackWeight,
        'birth_year': birthYear,
        'age_verified': ageVerified,
        if (safetyAcknowledgedAt != null)
          'safety_acknowledged_at': safetyAcknowledgedAt!.toIso8601String(),
        if (onboardingCompletedAt != null)
          'onboarding_completed_at': onboardingCompletedAt!.toIso8601String(),
      };

  Profile copyWith({
    DateTime? startDate,
    int? currentWeek,
    int? currentDay,
    String? status,
    DateTime? pausedAt,
    String? goal,
    String? displayName,
    bool? trackWeight,
    int? birthYear,
    bool? ageVerified,
    DateTime? safetyAcknowledgedAt,
    DateTime? onboardingCompletedAt,
  }) {
    return Profile(
      id: id,
      startDate: startDate ?? this.startDate,
      currentWeek: currentWeek ?? this.currentWeek,
      currentDay: currentDay ?? this.currentDay,
      status: status ?? this.status,
      pausedAt: pausedAt ?? this.pausedAt,
      goal: goal ?? this.goal,
      displayName: displayName ?? this.displayName,
      trackWeight: trackWeight ?? this.trackWeight,
      birthYear: birthYear ?? this.birthYear,
      ageVerified: ageVerified ?? this.ageVerified,
      safetyAcknowledgedAt: safetyAcknowledgedAt ?? this.safetyAcknowledgedAt,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
    );
  }
}
