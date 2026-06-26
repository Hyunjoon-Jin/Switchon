/// 스위치온 프로그램의 단계 정의 (오프라인 참조용).
/// Supabase `stage_rules` 테이블과 동일한 내용을 미러링하여,
/// 네트워크가 없어도 단계 추적 엔진(P1)이 동작하도록 합니다.
library;

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
  final String? notes;
}

class SwitchOnProgram {
  SwitchOnProgram._();

  /// 전체 프로그램 길이 (주). 3~4주차 진행 여부는 분기에 따름.
  static const int totalWeeks = 4;
  static const int daysPerWeek = 7;

  static const String medicalDisclaimer =
      '이 앱은 의료 행위나 의학적 조언을 제공하지 않습니다. '
      '건강 상태·지병·복약 여부에 따라 단식과 식단 제한이 무리가 될 수 있으니, '
      '시작 전과 진행 중에는 반드시 의사 등 전문가와 상담하세요.';

  static const List<StageRule> stages = [
    StageRule(
      id: 'w1_shake_only',
      weekNo: 1,
      dayFrom: 1,
      dayTo: 3,
      title: '1주차 (1~3일) · 셰이크 집중기',
      mission: [
        '단백질 셰이크 4회',
        '물 2L 이상',
        '수면 6시간 이상',
        '취침 4시간 전 식사 마감',
      ],
      allowedFoods: ['단백질 셰이크', '물', '블랙커피(소량)'],
      forbiddenFoods: ['일반식', '탄수화물', '당류', '간식'],
      notes: '가장 힘든 구간입니다. 무리가 느껴지면 멈추고 전문가와 상담하세요.',
    ),
    StageRule(
      id: 'w1_lunch_added',
      weekNo: 1,
      dayFrom: 4,
      dayTo: 7,
      title: '1주차 (4~7일) · 점심 저탄수 추가',
      mission: [
        '셰이크 (아침·저녁)',
        '점심 저탄수 식사 1회',
        '물 2L 이상',
        '수면 6시간 이상',
        '주 4회 이상 고강도 운동',
      ],
      allowedFoods: ['단백질 셰이크', '저탄수 식사(채소·단백질)', '물', '블랙커피'],
      forbiddenFoods: ['정제 탄수화물', '밀가루', '당류', '야식'],
      notes: '점심에 저탄수 식사를 추가합니다. 채소와 단백질 위주로 구성하세요.',
    ),
    StageRule(
      id: 'w2',
      weekNo: 2,
      dayFrom: 1,
      dayTo: 7,
      title: '2주차 · 일반식 비중 증가 + 주1회 24h 단식',
      mission: [
        '주 1회 24시간 단식',
        '일반식(저탄수 유지)',
        '물 2L 이상',
        '수면 6시간 이상',
        '주 4회 이상 고강도 운동',
      ],
      allowedFoods: ['저탄수 일반식', '견과류', '치즈', '블랙커피', '단백질 셰이크'],
      forbiddenFoods: ['정제 탄수화물', '당류', '가공식품', '음주'],
      notes: '주 1회 24시간 단식을 도입합니다. 견과류·치즈·블랙커피가 허용됩니다.',
    ),
    StageRule(
      id: 'w3_4',
      weekNo: 3,
      dayFrom: 1,
      dayTo: 7,
      title: '3~4주차 · 본격 체지방 감량기',
      mission: [
        '저탄수 일반식 유지',
        '주 1회 24시간 단식',
        '물 2L 이상',
        '수면 6시간 이상',
        '주 4회 이상 고강도 운동',
      ],
      allowedFoods: ['저탄수 일반식', '단백질', '채소', '견과류', '치즈', '블랙커피'],
      forbiddenFoods: ['밀가루', '정제 탄수화물', '당류', '가공식품', '음주'],
      notes: '근육량 회복 여부에 따라 반복/진행/유지기로 분기합니다. (분기 안내는 2차 기능)',
    ),
  ];

  /// 주차/일차에 해당하는 단계 규칙을 찾습니다. (단계 추적 엔진의 핵심)
  static StageRule stageFor(int week, int day) {
    for (final s in stages) {
      if (s.weekNo == week && day >= s.dayFrom && day <= s.dayTo) {
        return s;
      }
    }
    // 3주차 정의가 3~4주차를 포괄.
    if (week >= 3) {
      return stages.last;
    }
    return stages.first;
  }
}
