import '../../data/models/meal_log.dart';

/// 일별 단일 지표(칼로리·점수·식사수 추이용).
class DayMetric {
  const DayMetric({required this.date, required this.value, required this.has});
  final DateTime date;
  final double value;
  final bool has; // 해당 날짜에 데이터가 있는지
}

/// 식사·영양 통계 요약(선택 기간 기준).
class MealStats {
  const MealStats({
    required this.windowDays,
    required this.mealsCount,
    required this.analyzedCount,
    required this.calorieTrend,
    required this.scoreTrend,
    required this.mealCountTrend,
    required this.avgCalories,
    required this.avgCarbs,
    required this.avgProtein,
    required this.avgFat,
    required this.avgScore,
    required this.fitCount,
    required this.cautionCount,
    required this.violationCount,
    required this.recentAnalyzed,
  });

  final int windowDays;
  final int mealsCount; // 기간 내 식사(셰이크 제외) 수
  final int analyzedCount; // 기간 내 AI 분석된 식사 수

  final List<DayMetric> calorieTrend; // 일별 섭취 칼로리(분석분 합)
  final List<DayMetric> scoreTrend; // 일별 평균 AI 점수
  final List<DayMetric> mealCountTrend; // 일별 식사 수

  final int avgCalories; // 분석된 식사 1끼 평균 칼로리
  final int avgCarbs;
  final int avgProtein;
  final int avgFat;
  final int avgScore;

  final int fitCount;
  final int cautionCount;
  final int violationCount;

  /// 최근 분석한 식사(최대 5개, 최신순) — 화면 리스트용.
  final List<MealLog> recentAnalyzed;

  bool get hasNutrition => analyzedCount > 0;

  /// 탄·단·지 칼로리 비율(합 1.0). 데이터 없으면 0.
  (double, double, double) get macroRatio {
    final c = avgCarbs * 4, p = avgProtein * 4, f = avgFat * 9;
    final total = c + p + f;
    if (total <= 0) return (0, 0, 0);
    return (c / total, p / total, f / total);
  }
}

/// 식사 원자료 → 식사·영양 통계. 순수 함수.
MealStats computeMealStats({
  required List<MealLog> meals,
  required DateTime today,
  required int windowDays,
}) {
  final base = DateTime(today.year, today.month, today.day);
  final from = base.subtract(Duration(days: windowDays - 1));

  bool inWindow(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(from) && !day.isAfter(base);
  }

  // 날짜별 집계 버킷
  final calByDate = <String, double>{};
  final scoreSumByDate = <String, double>{};
  final scoreCntByDate = <String, int>{};
  final mealCntByDate = <String, int>{};

  var mealsCount = 0;
  var analyzedCount = 0;
  var sumCal = 0, sumCarb = 0, sumProt = 0, sumFat = 0, sumScore = 0;
  var fit = 0, caution = 0, violation = 0;

  for (final m in meals) {
    if (m.isShake) continue;
    if (!inWindow(m.loggedAt)) continue;
    mealsCount++;
    final key = _key(m.loggedAt);
    mealCntByDate[key] = (mealCntByDate[key] ?? 0) + 1;

    final ai = m.ai;
    if (ai == null) continue;
    analyzedCount++;
    sumScore += ai.score;
    scoreSumByDate[key] = (scoreSumByDate[key] ?? 0) + ai.score;
    scoreCntByDate[key] = (scoreCntByDate[key] ?? 0) + 1;
    if (ai.calories != null) {
      calByDate[key] = (calByDate[key] ?? 0) + ai.calories!;
      sumCal += ai.calories!;
      sumCarb += ai.carbsG ?? 0;
      sumProt += ai.proteinG ?? 0;
      sumFat += ai.fatG ?? 0;
    }
    switch (ai.verdict) {
      case 'fit':
        fit++;
        break;
      case 'violation':
        violation++;
        break;
      default:
        caution++;
    }
  }

  final calorieTrend = <DayMetric>[];
  final scoreTrend = <DayMetric>[];
  final mealCountTrend = <DayMetric>[];
  for (var i = windowDays - 1; i >= 0; i--) {
    final date = base.subtract(Duration(days: i));
    final key = _key(date);
    calorieTrend.add(DayMetric(
      date: date,
      value: calByDate[key] ?? 0,
      has: calByDate.containsKey(key),
    ));
    final sc = scoreCntByDate[key] ?? 0;
    scoreTrend.add(DayMetric(
      date: date,
      value: sc == 0 ? 0 : (scoreSumByDate[key]! / sc),
      has: sc > 0,
    ));
    mealCountTrend.add(DayMetric(
      date: date,
      value: (mealCntByDate[key] ?? 0).toDouble(),
      has: mealCntByDate.containsKey(key),
    ));
  }

  // 분석 칼로리가 있는 식사 수(평균 칼로리 분모)
  final calMeals = meals
      .where((m) => !m.isShake && inWindow(m.loggedAt) && m.ai?.calories != null)
      .length;

  int avg(int sum, int n) => n == 0 ? 0 : (sum / n).round();

  final recentAnalyzed = meals
      .where((m) => !m.isShake && m.ai != null)
      .toList()
    ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

  return MealStats(
    windowDays: windowDays,
    mealsCount: mealsCount,
    analyzedCount: analyzedCount,
    calorieTrend: calorieTrend,
    scoreTrend: scoreTrend,
    mealCountTrend: mealCountTrend,
    avgCalories: avg(sumCal, calMeals),
    avgCarbs: avg(sumCarb, calMeals),
    avgProtein: avg(sumProt, calMeals),
    avgFat: avg(sumFat, calMeals),
    avgScore: avg(sumScore, analyzedCount),
    fitCount: fit,
    cautionCount: caution,
    violationCount: violation,
    recentAnalyzed: recentAnalyzed.take(5).toList(),
  );
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
