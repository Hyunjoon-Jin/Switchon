/// 주차 분기 엔진 (2차 기능).
///
/// 3~4주차(본격 감량기) 종료 시 근육량 회복·목표 도달 여부로
/// 반복(repeat) / 진행(advance) / 유지(maintain) 를 안내합니다.
/// 의료 조언이 아니며, 자기 점검을 돕는 가이드입니다.
library;

enum BranchResult { repeat, advance, maintain }

extension BranchResultDb on BranchResult {
  String get db => switch (this) {
        BranchResult.repeat => 'repeat',
        BranchResult.advance => 'advance',
        BranchResult.maintain => 'maintain',
      };

  static BranchResult? fromDb(String? v) => switch (v) {
        'repeat' => BranchResult.repeat,
        'advance' => BranchResult.advance,
        'maintain' => BranchResult.maintain,
        _ => null,
      };
}

class BranchAnswers {
  const BranchAnswers({
    required this.muscleRecovered,
    required this.reachedGoal,
  });

  final bool muscleRecovered;
  final bool reachedGoal;
}

class BranchRecommendation {
  const BranchRecommendation({
    required this.result,
    required this.title,
    required this.message,
    required this.guidance,
  });

  final BranchResult result;
  final String title;
  final String message;
  final List<String> guidance;
}

class BranchEngine {
  BranchEngine._();

  /// 분기 질문이 의미 있는 주차인지(본격 감량기 = 3주차 이상).
  static bool isBranchWeek(int week) => week >= 3;

  static BranchRecommendation evaluate(BranchAnswers a) {
    // 근육량이 회복되지 않았으면 무리하지 않고 한 주 반복.
    if (!a.muscleRecovered) {
      return const BranchRecommendation(
        result: BranchResult.repeat,
        title: '한 주 더 반복해요',
        message: '근육량 회복이 우선이에요. 같은 단계를 한 주 반복하며 '
            '단백질과 근력 운동에 집중해 보세요.',
        guidance: [
          '단백질 섭취 충분히 (셰이크 활용)',
          '고강도·근력 운동 주 4회 유지',
          '수면 6시간 이상으로 회복 돕기',
          '무리한 추가 단식은 피하기',
        ],
      );
    }
    // 근육 회복 + 목표 미달 → 다음 단계로 진행하며 감량 지속.
    if (!a.reachedGoal) {
      return const BranchRecommendation(
        result: BranchResult.advance,
        title: '다음 단계로 진행해요',
        message: '근육량이 회복됐고 더 감량할 여지가 있어요. '
            '감량기를 이어가되 컨디션을 살피며 진행하세요.',
        guidance: [
          '저탄수 일반식 + 주 1회 24시간 단식 유지',
          '운동 강도 점진적으로 유지',
          '체중보다 컨디션·체지방 변화에 주목',
          '힘들면 언제든 멈추거나 전문가와 상담',
        ],
      );
    }
    // 근육 회복 + 목표 달성 → 유지기로 전환.
    return const BranchRecommendation(
      result: BranchResult.maintain,
      title: '유지기로 전환해요',
      message: '목표에 도달했어요. 요요를 막기 위해 천천히 일반식으로 '
          '돌아가는 유지기를 시작하세요.',
      guidance: [
        '탄수화물을 천천히·조금씩 늘리기',
        '단백질 섭취와 운동 습관은 유지',
        '주 1회 가벼운 단식으로 리듬 유지',
        '급격한 식사량 증가는 피하기',
      ],
    );
  }
}
