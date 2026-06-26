/// `progress` 테이블 모델 — 주차별 단계/분기 상태.
class WeekProgress {
  const WeekProgress({
    required this.weekNo,
    this.id,
    this.stage,
    this.branchResult,
    this.completedAt,
  });

  final String? id;
  final int weekNo;
  final String? stage;
  final String? branchResult; // repeat | advance | maintain
  final DateTime? completedAt;

  bool get isChecked => completedAt != null;

  factory WeekProgress.fromMap(Map<String, dynamic> map) {
    return WeekProgress(
      id: map['id'] as String?,
      weekNo: map['week_no'] as int,
      stage: map['stage'] as String?,
      branchResult: map['branch_result'] as String?,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
    );
  }
}
