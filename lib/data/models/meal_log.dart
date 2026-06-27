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
    this.aiScore,
    this.aiVerdict,
    this.aiFoods,
    this.aiFeedback,
    this.aiSuggestion,
    this.aiAnalyzedAt,
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

  // --- AI 식단 판독 결과 (analyze-meal Edge Function 이 기록) ---
  final int? aiScore; // 0~100
  final String? aiVerdict; // fit | caution | violation
  final String? aiFoods; // 인식한 음식(콤마 구분)
  final String? aiFeedback; // 피드백
  final String? aiSuggestion; // 식단 조절 제안
  final DateTime? aiAnalyzedAt;

  bool get isShake => type == 'shake';
  String get slotLabel => MealSlot.labelOf(mealSlot);

  /// AI 분석 결과가 있으면 묶어서 반환, 없으면 null.
  AiAnalysis? get ai {
    if (aiAnalyzedAt == null || aiScore == null || aiVerdict == null) {
      return null;
    }
    return AiAnalysis(
      score: aiScore!,
      verdict: aiVerdict!,
      foods: aiFoods ?? '',
      feedback: aiFeedback ?? '',
      suggestion: aiSuggestion ?? '',
      analyzedAt: aiAnalyzedAt!,
    );
  }

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
      aiScore: (map['ai_score'] as num?)?.toInt(),
      aiVerdict: map['ai_verdict'] as String?,
      aiFoods: map['ai_foods'] as String?,
      aiFeedback: map['ai_feedback'] as String?,
      aiSuggestion: map['ai_suggestion'] as String?,
      aiAnalyzedAt: map['ai_analyzed_at'] == null
          ? null
          : DateTime.parse(map['ai_analyzed_at'] as String),
    );
  }
}

/// AI 식단 판독 결과(표시용 묶음).
class AiAnalysis {
  const AiAnalysis({
    required this.score,
    required this.verdict,
    required this.foods,
    required this.feedback,
    required this.suggestion,
    required this.analyzedAt,
  });

  final int score; // 0~100
  final String verdict; // fit | caution | violation
  final String foods;
  final String feedback;
  final String suggestion;
  final DateTime analyzedAt;

  bool get isFit => verdict == 'fit';
  bool get isViolation => verdict == 'violation';

  /// 판정 한글 라벨.
  String get verdictLabel {
    switch (verdict) {
      case 'fit':
        return '적합';
      case 'caution':
        return '주의';
      case 'violation':
        return '단계 제한';
      default:
        return '분석';
    }
  }

  factory AiAnalysis.fromMap(Map<String, dynamic> map) {
    return AiAnalysis(
      score: (map['score'] as num?)?.toInt() ?? 0,
      verdict: (map['verdict'] as String?) ?? 'caution',
      foods: (map['foods'] as String?) ?? '',
      feedback: (map['feedback'] as String?) ?? '',
      suggestion: (map['suggestion'] as String?) ?? '',
      analyzedAt: DateTime.now(),
    );
  }
}
