/// 스위치온 프로그램의 단계 정의 (오프라인 참조용).
/// Supabase `stage_rules` 테이블과 동일한 내용을 미러링하여,
/// 네트워크가 없어도 단계 추적 엔진(P1)이 동작하도록 합니다.
///
/// 식단 내용은 박용우 「스위치온 다이어트」 프로그램의 공개 정보를 요약한 것으로,
/// 의료 조언이 아니며 판본에 따라 차이가 있을 수 있습니다. 정확한 식단은
/// 공식 책과 전문가 상담을 따르세요.
library;

/// 끼니별 식단 가이드.
class MealPlan {
  const MealPlan({
    required this.shake,
    this.lunch,
    this.dinner,
    this.snack,
    this.fruit,
  });

  final String shake; // 셰이크 안내
  final String? lunch; // 점심
  final String? dinner; // 저녁
  final String? snack; // 간식
  final String? fruit; // 과일 규칙
}

/// 식단표(주차·일차)의 끼니별 안내 — 사진의 '스위치온 다이어트 식단표' 기준.
class DayMeals {
  const DayMeals({
    required this.breakfast,
    required this.lunch,
    required this.snack,
    required this.dinner,
    this.isFasting = false,
  });

  final String breakfast; // 아침
  final String lunch; // 점심
  final String snack; // 간식
  final String dinner; // 저녁
  final bool isFasting; // 24시간 단식일(아침·점심·간식은 단식)

  /// 슬롯 키('breakfast'|'lunch'|'snack'|'dinner')로 해당 끼니 안내를 반환.
  String forSlot(String slot) {
    switch (slot) {
      case 'breakfast':
        return breakfast;
      case 'lunch':
        return lunch;
      case 'snack':
        return snack;
      case 'dinner':
        return dinner;
      default:
        return '';
    }
  }
}

class StageRule {
  const StageRule({
    required this.id,
    required this.weekNo,
    required this.dayFrom,
    required this.dayTo,
    required this.title,
    required this.mission,
    required this.allowedFoods,
    required this.forbiddenFoods,
    required this.mealPlan,
    this.exampleMeals = const [],
    this.notes,
  });

  final String id;
  final int weekNo;
  final int dayFrom;
  final int dayTo;
  final String title;
  final List<String> mission;
  final List<String> allowedFoods;
  final List<String> forbiddenFoods;
  final MealPlan mealPlan;
  final List<String> exampleMeals;
  final String? notes;
}

class SwitchOnProgram {
  SwitchOnProgram._();

  static const int totalWeeks = 4;
  static const int daysPerWeek = 7;

  static const String medicalDisclaimer =
      '이 앱은 의료 행위나 의학적 조언을 제공하지 않습니다. '
      '건강 상태·지병·복약 여부에 따라 단식과 식단 제한이 무리가 될 수 있으니, '
      '시작 전과 진행 중에는 반드시 의사 등 전문가와 상담하세요.';

  /// 모든 단계 공통 금지 식품.
  static const List<String> commonForbidden = [
    '밀가루 음식(빵·면·라면·과자)',
    '설탕·당류·디저트',
    '청량음료·주스',
    '커피믹스',
    '가당 우유·두유',
    '튀김·가공식품',
    '술',
  ];

  static const List<StageRule> stages = [
    // ── 1주차 1~3일 ───────────────────────────────────────────────
    StageRule(
      id: 'w1_shake_only',
      weekNo: 1,
      dayFrom: 1,
      dayTo: 3,
      title: '1주차 (1~3일) · 지방 대사 스위치 켜기',
      mission: [
        '단백질 셰이크 3회',
        '점심 저탄수 식사 1회',
        '물 2L 이상',
        '수면 6시간 이상',
        '취침 4시간 전 식사 마감',
      ],
      allowedFoods: [
        '단백질 셰이크',
        '녹황색 채소',
        '두부',
        '무가당 요거트',
        '코코넛오일',
        '물',
      ],
      forbiddenFoods: [
        '잡곡밥·곡물',
        '과일',
        ...commonForbidden,
      ],
      mealPlan: MealPlan(
        shake: '단백질 셰이크 3회 (아침·오후·저녁 중)',
        lunch: '저탄수 식사 — 두부와 녹황색 채소 위주 (밥 없이)',
        dinner: '셰이크 또는 가벼운 저탄수 채소식',
        snack: '무가당 요거트',
        fruit: '아직 제한해요',
      ),
      exampleMeals: [
        '두부 + 데친 녹황색 채소 (올리브오일·소금 약간)',
        '무가당 요거트 한 컵',
        '단백질 셰이크',
      ],
      notes: '가장 힘든 구간입니다. 무리가 느껴지면 멈추고 전문가와 상담하세요.',
    ),

    // ── 1주차 4~7일 ───────────────────────────────────────────────
    StageRule(
      id: 'w1_lunch_added',
      weekNo: 1,
      dayFrom: 4,
      dayTo: 7,
      title: '1주차 (4~7일) · 렙틴 저항성 개선',
      mission: [
        '단백질 셰이크 2~3회',
        '점심 저탄수 식사 (잡곡밥 반 공기)',
        '물 2L 이상',
        '수면 6시간 이상',
        '주 4회 이상 고강도 운동',
      ],
      allowedFoods: [
        '단백질 셰이크',
        '녹황색 채소·두부',
        '잡곡밥 반 공기',
        '생선',
        '닭고기(껍질 제외)',
        '해조류',
        '무가당 요거트',
      ],
      forbiddenFoods: [
        '과일',
        ...commonForbidden,
      ],
      mealPlan: MealPlan(
        shake: '단백질 셰이크 2~3회',
        lunch: '잡곡밥 반 공기 + 생선/닭가슴살 + 채소',
        dinner: '저탄수 단백질 식사 (밥 줄이기)',
        snack: '무가당 요거트',
        fruit: '아직 제한해요',
      ),
      exampleMeals: [
        '잡곡밥 반 공기 + 구운 생선 + 나물',
        '닭가슴살 샐러드 + 해조류 무침',
      ],
      notes: '점심에 저탄수 식사를 더합니다. 잡곡밥은 반 공기까지.',
    ),

    // ── 2주차 ────────────────────────────────────────────────────
    StageRule(
      id: 'w2',
      weekNo: 2,
      dayFrom: 1,
      dayTo: 7,
      title: '2주차 · 근육 회복 + 인슐린 저항성 개선',
      mission: [
        '단백질 셰이크 2회 (아침·오후 간식)',
        '점심 저탄수 / 저녁 무탄수',
        '주 1회 24시간 단식',
        '물 2L 이상 · 수면 6시간 이상',
        '주 4회 이상 고강도 운동',
      ],
      allowedFoods: [
        '저탄수 일반식',
        '콩류·견과류',
        '치즈·우유',
        '블랙커피(오전 1잔)',
        '생선·해산물',
        '닭고기·수육·달걀',
        '채소·해조류·버섯',
      ],
      forbiddenFoods: [
        '과일',
        ...commonForbidden,
      ],
      mealPlan: MealPlan(
        shake: '단백질 셰이크 2회 (아침·오후 간식)',
        lunch: '저탄수 — 잡곡밥 소량 + 단백질 + 채소',
        dinner: '무탄수 — 생선·수육 + 채소 (밥 없이 배부르게)',
        snack: '견과류 한 줌 · 블랙커피(오전 1잔)',
        fruit: '아직 제한해요',
      ),
      exampleMeals: [
        '점심: 현미밥 소량 + 두부조림 + 나물',
        '저녁: 고등어구이 + 쌈채소 (밥 없이)',
        '간식: 견과류 한 줌 + 블랙커피',
      ],
      notes: '주 1회 24시간 단식을 도입합니다. 견과류·치즈·블랙커피가 허용됩니다.',
    ),

    // ── 3주차 ────────────────────────────────────────────────────
    StageRule(
      id: 'w3',
      weekNo: 3,
      dayFrom: 1,
      dayTo: 7,
      title: '3주차 · 본격 체지방 감량',
      mission: [
        '단백질 셰이크 2회',
        '점심 저탄수 / 저녁 무탄수',
        '주 1회 24시간 단식',
        '물 2L 이상 · 수면 6시간 이상',
        '주 4회 이상 고강도 운동',
      ],
      allowedFoods: [
        '두부·연두부',
        '채소(양배추·브로콜리·오이 등)',
        '아보카도',
        '오일류(올리브·코코넛·들기름)',
        '생선·해산물',
        '닭고기·수육·달걀',
        '잡곡밥·현미·퀴노아·콩류',
        '견과류 1줌 · 블랙커피',
      ],
      forbiddenFoods: [
        '과일',
        ...commonForbidden,
      ],
      mealPlan: MealPlan(
        shake: '단백질 셰이크 2회',
        lunch: '저탄수 — 퀴노아/현미 소량 + 단백질 + 채소',
        dinner: '무탄수 — 등푸른 생선·수육·샤브샤브 + 채소',
        snack: '견과류 한 줌',
        fruit: '아직 제한해요',
      ),
      exampleMeals: [
        '점심: 퀴노아 + 닭가슴살 + 아보카도 샐러드',
        '저녁: 수육 + 쌈채소 + 된장 (밥 없이)',
        '저녁: 해물 샤브샤브 + 버섯·채소',
      ],
      notes: '체지방이 본격적으로 빠지는 구간. 저녁은 무탄수로 단백질을 배부르게.',
    ),

    // ── 4주차 ────────────────────────────────────────────────────
    StageRule(
      id: 'w4',
      weekNo: 4,
      dayFrom: 1,
      dayTo: 7,
      title: '4주차 · 업그레이드 (과일 추가)',
      mission: [
        '단백질 셰이크 2회',
        '점심 저탄수 / 저녁 무탄수',
        '과일 하루 1개까지',
        '물 2L 이상 · 수면 6시간 이상',
        '주 4회 이상 고강도 운동',
      ],
      allowedFoods: [
        '3주차 허용식품 전체',
        '과일 하루 1개(베리류·방울토마토·바나나·밤)',
        '단호박·토마토',
      ],
      forbiddenFoods: [
        ...commonForbidden,
      ],
      mealPlan: MealPlan(
        shake: '단백질 셰이크 2회',
        lunch: '저탄수 — 잡곡 소량 + 단백질 + 채소',
        dinner: '무탄수 — 생선·수육 + 채소',
        snack: '견과류 한 줌',
        fruit: '하루 1개 (베리류·방울토마토 등 권장)',
      ),
      exampleMeals: [
        '아침: 무가당 요거트 + 베리류 약간',
        '점심: 현미밥 소량 + 닭가슴살 + 채소',
        '저녁: 샤브샤브 + 채소 (밥 없이)',
      ],
      notes: '근육량 회복 여부에 따라 반복/진행/유지기로 분기합니다. (주차 점검 참고)',
    ),
  ];

  // 끼니 식단표에 쓰는 식사 유형 라벨.
  static const String mShake = '셰이크';
  static const String mLowCarb = '저탄수화물식';
  static const String mNoCarb = '탄수제한식';
  static const String mFast = '24시간 단식';

  /// 24시간 단식을 진행하는 일차 (주차 → 일차 집합).
  static const Map<int, Set<int>> fastingDays = {
    2: {2},
    3: {2, 6},
    4: {2, 4, 6},
  };

  static bool isFastingDay(int week, int day) =>
      (fastingDays[week] ?? const <int>{}).contains(day);

  /// 주차·일차별 끼니 식단표(아침/점심/간식/저녁).
  /// 식단표 사진 기준이며, 24시간 단식일은 아침·점심·간식이 단식입니다.
  static DayMeals dayMeals(int week, int day) {
    final w = week.clamp(1, totalWeeks).toInt();
    final d = day.clamp(1, daysPerWeek).toInt();
    final fast = isFastingDay(w, d);

    // 아침: 단식일이 아니면 셰이크.
    final breakfast = fast ? mFast : mShake;

    // 점심: 1주차 1~3일은 셰이크, 그 외에는 저탄수화물식.
    final String lunch;
    if (fast) {
      lunch = mFast;
    } else if (w == 1 && d <= 3) {
      lunch = mShake;
    } else {
      lunch = mLowCarb;
    }

    // 간식: 단식일이 아니면 셰이크.
    final snack = fast ? mFast : mShake;

    // 저녁: 1주차는 셰이크, 2·3주차는 탄수제한식,
    //       4주차는 단식일이면 저탄수화물식 / 그 외엔 탄수제한식.
    final String dinner;
    if (w == 1) {
      dinner = mShake;
    } else if (w == 4) {
      dinner = fast ? mLowCarb : mNoCarb;
    } else {
      dinner = mNoCarb;
    }

    return DayMeals(
      breakfast: breakfast,
      lunch: lunch,
      snack: snack,
      dinner: dinner,
      isFasting: fast,
    );
  }

  /// 주차/일차에 해당하는 단계 규칙을 찾습니다. (단계 추적 엔진의 핵심)
  static StageRule stageFor(int week, int day) {
    for (final s in stages) {
      if (s.weekNo == week && day >= s.dayFrom && day <= s.dayTo) {
        return s;
      }
    }
    // 주 단위 단계(2~4주차) 폴백.
    for (final s in stages) {
      if (s.weekNo == week) return s;
    }
    return week >= 4 ? stages.last : stages.first;
  }
}
