import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/meal_log.dart';

/// 오늘의 식단 기록(셰이크/식사) 컨트롤러.
final mealsControllerProvider =
    AsyncNotifierProvider<MealsController, List<MealLog>>(MealsController.new);

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

  Future<void> addShake() async {
    await ref.read(supabaseServiceProvider).addShake();
    await _reload();
  }

  Future<void> addMeal({String? memo, String? photoPath}) async {
    await ref
        .read(supabaseServiceProvider)
        .addMeal(memo: memo, photoPath: photoPath);
    await _reload();
  }

  Future<void> delete(String id) async {
    await ref.read(supabaseServiceProvider).deleteMeal(id);
    await _reload();
  }
}

/// 오늘 셰이크 총 횟수.
int shakeCountOf(List<MealLog> logs) =>
    logs.where((m) => m.isShake).fold(0, (sum, m) => sum + m.shakeCount);
