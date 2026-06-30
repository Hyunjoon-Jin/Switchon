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
    this.aiCalories,
    this.aiCarbsG,
    this.aiProteinG,
    this.aiFatG,
    this.aiConfidence,
  });

  final String id;
  final DateTime loggedAt;
  final String type; // meal | (legacy) shake
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
  final int? aiCalories; // kcal(추정)
  final int? aiCarbsG;
  final int? aiProteinG;
  final int? aiFatG;
  final String? aiConfidence; // high | medium | low

  /// (레거시) 셰이크 기록 여부 — 셰이크 기록 기능은 제거됐으나,
  /// 과거에 쌓인 type='shake' 행을 목록·통계에서 걸러내기 위해 유지합니다.
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
      calories: aiCalories,
      carbsG: aiCarbsG,
      proteinG: aiProteinG,
      fatG: aiFatG,
      confidence: aiConfidence,
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
      loggedAt: DateTime.parse(map['logged_at'] as String).toLocal(),
      type: map['type'] as String,
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
      aiCalories: (map['ai_calories'] as num?)?.toInt(),
      aiCarbsG: (map['ai_carbs_g'] as num?)?.toInt(),
      aiProteinG: (map['ai_protein_g'] as num?)?.toInt(),
      aiFatG: (map['ai_fat_g'] as num?)?.toInt(),
      aiConfidence: map['ai_confidence'] as String?,
    );
  }
}

/// AI 식단 판독 결과(표시용 묶음 + 저장용).
class AiAnalysis {
  const AiAnalysis({
    required this.score,
    required this.verdict,
    required this.foods,
    required this.feedback,
    required this.suggestion,
    required this.analyzedAt,
    this.calories,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.confidence,
  });

  final int score; // 0~100
  final String verdict; // fit | caution | violation
  final String foods;
  final String feedback;
  final String suggestion;
  final DateTime analyzedAt;
  final int? calories; // kcal(추정)
  final int? carbsG;
  final int? proteinG;
  final int? fatG;
  final String? confidence; // high | medium | low

  bool get isFit => verdict == 'fit';
  bool get isViolation => verdict == 'violation';
  bool get hasNutrition => calories != null;

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

  /// 신뢰도 한글 라벨(없으면 null).
  String? get confidenceLabel {
    switch (confidence) {
      case 'high':
        return '추정 신뢰도 높음';
      case 'medium':
        return '추정 신뢰도 보통';
      case 'low':
        return '추정 신뢰도 낮음';
      default:
        return null;
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
      calories: (map['calories'] as num?)?.toInt(),
      carbsG: (map['carbs_g'] as num?)?.toInt(),
      proteinG: (map['protein_g'] as num?)?.toInt(),
      fatG: (map['fat_g'] as num?)?.toInt(),
      confidence: map['confidence'] as String?,
    );
  }

  /// meal_logs 저장용 컬럼 맵(저장 전 분석 결과를 함께 기록할 때 사용).
  Map<String, dynamic> toColumns() => {
        'ai_score': score,
        'ai_verdict': verdict,
        'ai_foods': foods,
        'ai_feedback': feedback,
        'ai_suggestion': suggestion,
        'ai_calories': calories,
        'ai_carbs_g': carbsG,
        'ai_protein_g': proteinG,
        'ai_fat_g': fatG,
        'ai_confidence': confidence,
        'ai_analyzed_at': analyzedAt.toUtc().toIso8601String(),
      };
}
