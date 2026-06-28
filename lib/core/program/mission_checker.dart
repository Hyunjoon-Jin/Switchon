import '../../data/models/daily_log.dart';
import '../../data/models/fasting_session.dart';
import '../../data/models/meal_log.dart';

/// 자동 미션 체크에 필요한 컨텍스트.
class MissionContext {
  const MissionContext({
    required this.log,
    required this.shakeCount,
    required this.meals,
    this.fastingSession,
    this.weeklyExerciseCount = 0,
    this.weeklyFasting24Count = 0,
  });

  final DailyLog log;
  final int shakeCount; // 오늘 셰이크 총 횟수
  final List<MealLog> meals; // 오늘 식사 목록
  final FastingSession? fastingSession; // 현재 활성 단식 세션
  final int weeklyExerciseCount; // 이번 주 운동 완료 일수
  final int weeklyFasting24Count; // 이번 주 24h 단식 완료 횟수
}

/// 미션 라벨이 자동 달성됐는지 판단합니다 (순수 함수).
/// 판단할 수 없는 미션(식품 품질 제한 등)은 false를 반환합니다.
bool autoCheckMission(String label, MissionContext ctx) {
  // ── 단백질 셰이크 ──────────────────────────────────────────────
  if (label.contains('셰이크 3회')) return ctx.shakeCount >= 3;
  if (label.contains('셰이크 2~3회')) return ctx.shakeCount >= 2;
  if (label.contains('셰이크 2회')) return ctx.shakeCount >= 2;

  // ── 물·수면 복합 (먼저 매칭) ───────────────────────────────────
  if (label.contains('물 2L') && label.contains('수면 6')) {
    return ctx.log.waterMl >= DailyLog.waterTargetMl &&
        (ctx.log.sleepHours ?? 0) >= DailyLog.sleepTargetHours;
  }

  // ── 물 단독 ───────────────────────────────────────────────────
  if (label.contains('물 2L')) return ctx.log.waterMl >= DailyLog.waterTargetMl;

  // ── 수면 단독 ─────────────────────────────────────────────────
  if (label.contains('수면 6시간')) {
    return (ctx.log.sleepHours ?? 0) >= DailyLog.sleepTargetHours;
  }

  // ── 주간 운동 ─────────────────────────────────────────────────
  if (label.contains('주 4회') && label.contains('운동')) {
    return ctx.weeklyExerciseCount >= 4;
  }

  // ── 주간 24시간 단식 ──────────────────────────────────────────
  if (label.contains('24시간 단식')) return ctx.weeklyFasting24Count >= 1;

  // ── 취침 4시간 전 식사 마감 ────────────────────────────────────
  if (label.contains('취침 4시간 전')) return _checkBedtimeMeal(ctx);

  // ── 점심 + 저녁 복합 ──────────────────────────────────────────
  if (label.contains('점심') && label.contains('저녁')) {
    return _hasSlotMeal(ctx.meals, 'lunch') &&
        _hasSlotMeal(ctx.meals, 'dinner');
  }

  // ── 점심 단독 ─────────────────────────────────────────────────
  if (label.contains('점심')) return _hasSlotMeal(ctx.meals, 'lunch');

  // '과일 하루 1개까지' 등 제한 규칙은 자동 판단 불가 → 수동 유지
  return false;
}

bool _checkBedtimeMeal(MissionContext ctx) {
  final sleepStartMin = ctx.log.sleepStartMinutes;
  if (sleepStartMin == null) return false;

  final regularMeals = ctx.meals.where((m) => !m.isShake).toList();
  if (regularMeals.isEmpty) return true; // 식사 기록 없음 → 조건 충족

  final lastMeal = regularMeals.reduce(
      (a, b) => a.loggedAt.isAfter(b.loggedAt) ? a : b);
  final lastMealMin =
      lastMeal.loggedAt.hour * 60 + lastMeal.loggedAt.minute;

  // 자정 넘김 처리: 취침 시각이 마지막 식사보다 이르면 취침이 다음날
  final adjustedSleep =
      lastMealMin > sleepStartMin ? sleepStartMin + 1440 : sleepStartMin;

  return (adjustedSleep - lastMealMin) >= 240;
}

bool _hasSlotMeal(List<MealLog> meals, String slot) =>
    meals.any((m) => !m.isShake && m.mealSlot == slot);
