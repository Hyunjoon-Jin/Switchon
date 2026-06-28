import '../../data/models/daily_log.dart';
import '../../data/models/fasting_session.dart';
import '../../data/models/meal_log.dart';
import '../../data/models/recovery.dart';

/// 미준수 감지 엔진 — 최근 기록을 보고 "회복 신호"를 한 개 산출(순수 함수).
///
/// 톤 원칙: 비난·죄책감 금지, 극단 보상(폭식 후 굶기 등) 절대 권장 안 함.
/// 우선순위: 식단 위반(오늘/어제) → 저달성(어제) → 단식 취소 → 연속 미기록.
class RecoveryEngine {
  RecoveryEngine._();

  static RecoverySignal? detect({
    required DateTime today,
    required List<DailyLog> recentLogs,
    required List<MealLog> recentMeals,
    required List<FastingSession> recentFastings,
  }) {
    final base = DateTime(today.year, today.month, today.day);
    final yesterday = base.subtract(const Duration(days: 1));

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    // 1) 식단 위반(오늘/어제)
    final violated = recentMeals.where((m) {
      final d = DateTime(m.loggedAt.year, m.loggedAt.month, m.loggedAt.day);
      final recent = sameDay(d, base) || sameDay(d, yesterday);
      final isViolation = m.ruleViolation == true || (m.ai?.isViolation ?? false);
      return recent && isViolation;
    }).toList();
    if (violated.isNotEmpty) {
      return RecoverySignal(
        kind: RecoveryKind.violation,
        date: base,
        title: '괜찮아요, 한 끼로 무너지지 않아요',
        message: '단계에 안 맞는 식사가 있었네요. '
            '자책하지 말고 다음 끼니부터 자연스럽게 이어가면 돼요.',
        tips: const [
          '다음 끼니는 채소 + 단백질 위주로 가볍게',
          '물을 한두 잔 충분히',
          '굶거나 폭식으로 "보상"하지 않기 — 평소 리듬 유지',
        ],
        suggestAdjust: false,
      );
    }

    // 2) 저달성(어제 기록이 있고 달성률 < 0.5)
    final byDate = <String, DailyLog>{};
    for (final l in recentLogs) {
      byDate[_key(l.logDate)] = l;
    }
    final yLog = byDate[_key(yesterday)];
    if (yLog != null && yLog.completionRate < 0.5) {
      return RecoverySignal(
        kind: RecoveryKind.lowCompletion,
        date: yesterday,
        title: '어제는 조금 흔들렸네요 — 다시 가볍게',
        message: '완벽하지 않아도 괜찮아요. 작은 것 하나부터 다시 시작해요.',
        tips: const [
          '오늘 체크리스트 중 가장 쉬운 한 가지부터',
          '물 한 잔 · 가벼운 산책으로 워밍업',
          '버겁다면 일정을 하루 늦춰도 좋아요',
        ],
        suggestAdjust: true,
      );
    }

    // 3) 단식 취소(최근 2일 내)
    final canceled = recentFastings.where((f) {
      if (f.status != 'canceled' || f.endedAt == null) return false;
      final diff = base.difference(
          DateTime(f.endedAt!.year, f.endedAt!.month, f.endedAt!.day)).inDays;
      return diff >= 0 && diff <= 1;
    }).toList();
    if (canceled.isNotEmpty) {
      return RecoverySignal(
        kind: RecoveryKind.fastCancel,
        date: base,
        title: '단식을 멈췄군요 — 잘한 선택일 수 있어요',
        message: '컨디션이 우선이에요. 무리한 단식보다 꾸준함이 더 중요해요.',
        tips: const [
          '다음엔 14시간부터 가볍게 다시 시도',
          '공복이 힘들면 물·블랙커피로 완화',
          '몸이 보내는 신호를 존중하기',
        ],
        suggestAdjust: false,
      );
    }

    // 4) 연속 미기록(어제·그제 모두 기록 없음)
    final dayBefore = base.subtract(const Duration(days: 2));
    final hasYLog = byDate.containsKey(_key(yesterday));
    final hasDBLog = byDate.containsKey(_key(dayBefore));
    bool hasMealOn(DateTime d) => recentMeals.any((m) => sameDay(
        DateTime(m.loggedAt.year, m.loggedAt.month, m.loggedAt.day), d));
    final gap = !hasYLog && !hasDBLog && !hasMealOn(yesterday) && !hasMealOn(dayBefore);
    if (gap) {
      return RecoverySignal(
        kind: RecoveryKind.gap,
        date: base,
        title: '며칠 쉬어도 괜찮아요 — 다시 환영해요',
        message: '돌아온 것만으로 충분해요. 부담 없이 오늘 한 가지만 기록해볼까요?',
        tips: const [
          '오늘 한 끼만 가볍게 기록',
          '필요하면 일정을 미뤄(하루 연장) 천천히',
          '완벽보다 다시 시작하는 게 중요해요',
        ],
        suggestAdjust: true,
      );
    }

    return null;
  }
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
