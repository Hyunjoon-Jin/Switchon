/// 끼니 구분.
class MealSlot {
  const MealSlot(this.id, this.label);
  final String id;
  final String label;

  static const breakfast = MealSlot('breakfast', '아침');
  static const lunch = MealSlot('lunch', '점심');
  static const dinner = MealSlot('dinner', '저녁');
  static const snack = MealSlot('snack', '간식');

  static const all = [breakfast, lunch, dinner, snack];

  static String labelOf(String? id) {
    for (final s in all) {
      if (s.id == id) return s.label;
    }
    return '식사';
  }
}

/// `meal_logs` 테이블 모델 — 셰이크/식사 기록.
class MealLog {
  const MealLog({
    required this.id,
    required this.loggedAt,
    required this.type,
    this.shakeCount = 0,
    this.mealSlot,
    this.photoPath = '',
    this.photoUrls = const [],
    this.memo,
    this.foodTags = const [],
    this.ruleViolation,
  });

  final String id;
  final DateTime loggedAt;
  final String type; // shake | meal
  final int shakeCount;
  final String? mealSlot; // breakfast | lunch | dinner | snack
  final String photoPath; // (레거시) 단일 사진 경로
  final List<String> photoUrls; // 다중 사진 경로(스토리지 경로)
  final String? memo;
  final List<String> foodTags;
  final bool? ruleViolation;

  bool get isShake => type == 'shake';
  String get slotLabel => MealSlot.labelOf(mealSlot);

  /// 표시용 사진 경로 목록(신규 photo_urls 우선, 없으면 레거시 photo_path).
  List<String> get photos {
    if (photoUrls.isNotEmpty) return photoUrls;
    if (photoPath.isNotEmpty) return [photoPath];
    return const [];
  }

  bool get hasPhoto => photos.isNotEmpty;

  factory MealLog.fromMap(Map<String, dynamic> map) {
    return MealLog(
      id: map['id'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      type: map['type'] as String,
      shakeCount: (map['shake_count'] as int?) ?? 0,
      mealSlot: map['meal_slot'] as String?,
      photoPath: (map['photo_url'] as String?) ?? '',
      photoUrls: ((map['photo_urls'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      memo: map['memo'] as String?,
      foodTags: ((map['food_tags'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      ruleViolation: map['rule_violation'] as bool?,
    );
  }
}
