/// 회복 이벤트 종류.
enum RecoveryKind { violation, lowCompletion, fastCancel, gap }

extension RecoveryKindX on RecoveryKind {
  String get id {
    switch (this) {
      case RecoveryKind.violation:
        return 'violation';
      case RecoveryKind.lowCompletion:
        return 'low_completion';
      case RecoveryKind.fastCancel:
        return 'fast_cancel';
      case RecoveryKind.gap:
        return 'gap';
    }
  }

  static RecoveryKind fromId(String id) {
    switch (id) {
      case 'low_completion':
        return RecoveryKind.lowCompletion;
      case 'fast_cancel':
        return RecoveryKind.fastCancel;
      case 'gap':
        return RecoveryKind.gap;
      default:
        return RecoveryKind.violation;
    }
  }
}

/// 홈에 노출할 회복 신호 — 격려 + 보정 팁 + 계획 조정 제안 여부.
class RecoverySignal {
  const RecoverySignal({
    required this.kind,
    required this.date,
    required this.title,
    required this.message,
    required this.tips,
    this.suggestAdjust = false,
  });

  final RecoveryKind kind;
  final DateTime date; // 신호의 기준 날짜
  final String title; // 격려 헤드라인
  final String message; // 부드러운 본문
  final List<String> tips; // 보정 팁(극단 보상 금지)
  final bool suggestAdjust; // 계획 조정(하루 연장/일시정지) 권유 여부

  /// 세션 내 중복 노출 방지용 키.
  String get dismissKey =>
      '${kind.id}-${date.year}-${date.month}-${date.day}';
}
