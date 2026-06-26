/// 규칙 위반 감지 엔진 (2차 기능).
///
/// 음식 사진 자동 인식 대신 **사용자가 음식 태그를 선택**하면,
/// 현재 주차 단계의 규칙셋과 대조해 위반/주의를 판정합니다.
library;

class FoodTag {
  const FoodTag(this.id, this.label);
  final String id;
  final String label;
}

/// 선택 가능한 음식 태그 카탈로그.
class FoodTags {
  FoodTags._();

  static const protein = FoodTag('protein', '단백질(고기·생선)');
  static const vegetable = FoodTag('vegetable', '채소');
  static const shake = FoodTag('shake', '단백질 셰이크');
  static const egg = FoodTag('egg', '계란');
  static const nuts = FoodTag('nuts', '견과류');
  static const cheese = FoodTag('cheese', '치즈');
  static const blackCoffee = FoodTag('black_coffee', '블랙커피');
  static const rice = FoodTag('rice', '밥·곡물');
  static const refinedCarbs = FoodTag('refined_carbs', '밀가루·면·빵');
  static const sugar = FoodTag('sugar', '당류·디저트');
  static const fruit = FoodTag('fruit', '과일');
  static const processed = FoodTag('processed', '가공식품');
  static const fried = FoodTag('fried', '튀김');
  static const alcohol = FoodTag('alcohol', '술');

  static const all = <FoodTag>[
    protein,
    vegetable,
    shake,
    egg,
    nuts,
    cheese,
    blackCoffee,
    rice,
    refinedCarbs,
    sugar,
    fruit,
    processed,
    fried,
    alcohol,
  ];

  static FoodTag? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// 단계별 식단 규칙셋.
/// - [allowOnly] 가 비어있지 않으면: 그 외 모든 태그는 위반(셰이크 집중기).
/// - 아니면 [forbidden] 은 위반, [caution] 은 주의.
class StageDietRule {
  const StageDietRule({
    this.allowOnly = const {},
    this.forbidden = const {},
    this.caution = const {},
  });

  final Set<String> allowOnly;
  final Set<String> forbidden;
  final Set<String> caution;
}

class RuleEvaluation {
  const RuleEvaluation({
    required this.week,
    required this.violations,
    required this.cautions,
  });

  final int week;
  final List<FoodTag> violations;
  final List<FoodTag> cautions;

  bool get isViolation => violations.isNotEmpty;
  bool get hasCaution => cautions.isNotEmpty;
  bool get isClean => violations.isEmpty && cautions.isEmpty;

  /// 부드러운 안내 문구. 예: "3주차엔 밀가루·면·빵, 당류·디저트 섭취를 제한해요."
  String? get message {
    if (isViolation) {
      final names = violations.map((t) => t.label).join(', ');
      return '$week주차엔 $names 섭취를 제한해요. 다음 단계에서 다시 만나요!';
    }
    if (hasCaution) {
      final names = cautions.map((t) => t.label).join(', ');
      return '$names 은(는) 조금만 — 양을 줄이는 걸 권해요.';
    }
    return null;
  }
}

class DietRules {
  DietRules._();

  /// stage.id → 규칙셋
  static const Map<String, StageDietRule> _byStage = {
    // 1주차 1~3일: 셰이크·블랙커피만 허용, 나머지는 위반.
    'w1_shake_only': StageDietRule(
      allowOnly: {'shake', 'black_coffee'},
    ),
    // 1주차 4~7일: 저탄수 식사 추가. 견과류·치즈는 아직 권장 X(주의).
    'w1_lunch_added': StageDietRule(
      forbidden: {
        'refined_carbs',
        'sugar',
        'rice',
        'processed',
        'fried',
        'alcohol',
      },
      caution: {'fruit', 'nuts', 'cheese'},
    ),
    // 2주차: 견과류·치즈 허용. 정제탄수·당류·가공·튀김·음주 제한, 곡물·과일 주의.
    'w2': StageDietRule(
      forbidden: {'refined_carbs', 'sugar', 'processed', 'fried', 'alcohol'},
      caution: {'rice', 'fruit'},
    ),
    // 3~4주차: 본격 감량기. 2주차와 동일 기조.
    'w3_4': StageDietRule(
      forbidden: {'refined_carbs', 'sugar', 'processed', 'fried', 'alcohol'},
      caution: {'rice', 'fruit'},
    ),
  };

  static StageDietRule ruleFor(String stageId) =>
      _byStage[stageId] ?? const StageDietRule();

  static RuleEvaluation evaluate({
    required String stageId,
    required int week,
    required List<String> tagIds,
  }) {
    final rule = ruleFor(stageId);
    final violations = <FoodTag>[];
    final cautions = <FoodTag>[];

    for (final id in tagIds) {
      final tag = FoodTags.byId(id);
      if (tag == null) continue;
      final blockedByWhitelist =
          rule.allowOnly.isNotEmpty && !rule.allowOnly.contains(id);
      if (blockedByWhitelist || rule.forbidden.contains(id)) {
        violations.add(tag);
      } else if (rule.caution.contains(id)) {
        cautions.add(tag);
      }
    }

    return RuleEvaluation(
      week: week,
      violations: violations,
      cautions: cautions,
    );
  }
}
