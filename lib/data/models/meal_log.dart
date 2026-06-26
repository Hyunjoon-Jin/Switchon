/// `meal_logs` 테이블 모델 — 셰이크/식사 기록.
class MealLog {
  const MealLog({
    required this.id,
    required this.loggedAt,
    required this.type,
    this.shakeCount = 0,
    this.photoPath,
    this.memo,
    this.foodTags = const [],
    this.ruleViolation,
  });

  final String id;
  final DateTime loggedAt;
  final String type; // shake | meal
  final int shakeCount;
  final String photoPath; // storage 경로(예: <uid>/<file>), 없으면 빈 문자열
  final String? memo;
  final List<String> foodTags;
  final bool? ruleViolation;

  bool get isShake => type == 'shake';
  bool get hasPhoto => photoPath.isNotEmpty;

  factory MealLog.fromMap(Map<String, dynamic> map) {
    return MealLog(
      id: map['id'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      type: map['type'] as String,
      shakeCount: (map['shake_count'] as int?) ?? 0,
      photoPath: (map['photo_url'] as String?) ?? '',
      memo: map['memo'] as String?,
      foodTags: ((map['food_tags'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      ruleViolation: map['rule_violation'] as bool?,
    );
  }
}
