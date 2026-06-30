import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/meal_log.dart';

/// 오늘의 식단 기록(셰이크/식사) 컨트롤러.
final mealsControllerProvider =
    AsyncNotifierProvider<MealsController, List<MealLog>>(MealsController.new);

/// 특정 날짜의 식단 기록(히스토리 보기용). 날짜는 자정 기준으로 넘겨주세요.
final mealsForDateProvider =
    FutureProvider.family<List<MealLog>, DateTime>((ref, date) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseServiceProvider).fetchMealsForDate(date);
});

class MealsController extends AsyncNotifier<List<MealLog>> {
  @override
  Future<List<MealLog>> build() {
    ref.watch(authStateProvider);
    return ref.watch(supabaseServiceProvider).fetchTodayMeals();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(
      () => ref.read(supabaseServiceProvider).fetchTodayMeals(),
    );
  }

  Future<void> addMeal({
    String? mealSlot,
    String? memo,
    List<String> photoUrls = const [],
    DateTime? loggedAt,
    List<String> foodTags = const [],
    bool? ruleViolation,
    AiAnalysis? ai,
  }) async {
    await ref.read(supabaseServiceProvider).addMeal(
          mealSlot: mealSlot,
          memo: memo,
          photoUrls: photoUrls,
          loggedAt: loggedAt,
          foodTags: foodTags,
          ruleViolation: ruleViolation,
          ai: ai,
        );
    await _reload();
  }

  Future<void> updateMeal(
    String id, {
    String? mealSlot,
    String? memo,
    List<String>? photoUrls,
    DateTime? loggedAt,
    List<String>? foodTags,
    bool? ruleViolation,
    AiAnalysis? ai,
  }) async {
    await ref.read(supabaseServiceProvider).updateMeal(
          id,
          mealSlot: mealSlot,
          memo: memo,
          photoUrls: photoUrls,
          loggedAt: loggedAt,
          foodTags: foodTags,
          ruleViolation: ruleViolation,
          ai: ai,
        );
    await _reload();
  }

  Future<void> delete(String id) async {
    await ref.read(supabaseServiceProvider).deleteMeal(id);
    await _reload();
  }
}
