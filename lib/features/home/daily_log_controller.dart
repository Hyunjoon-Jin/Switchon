import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/daily_log.dart';

/// 오늘의 체크리스트(daily_log) 상태 + 낙관적 업데이트 컨트롤러.
final dailyLogControllerProvider =
    AsyncNotifierProvider<DailyLogController, DailyLog>(DailyLogController.new);

class DailyLogController extends AsyncNotifier<DailyLog> {
  @override
  Future<DailyLog> build() {
    // 인증 상태가 바뀌면 다시 로드.
    ref.watch(authStateProvider);
    return ref.watch(supabaseServiceProvider).fetchDailyLog(DateTime.now());
  }

  Future<void> _mutate(DailyLog Function(DailyLog current) transform) async {
    final service = ref.read(supabaseServiceProvider);
    final prev = state.valueOrNull ?? await service.fetchDailyLog(DateTime.now());
    final next = transform(prev);
    state = AsyncData(next); // 낙관적 반영
    try {
      final saved = await service.saveDailyLog(next);
      state = AsyncData(saved);
    } catch (e) {
      state = AsyncData(prev); // 실패 시 롤백
      rethrow;
    }
  }

  /// 끼니 슬롯(아침/점심/간식/저녁) 체크 토글. missionDone 에 슬롯 키로 저장.
  Future<void> toggleMeal(String slot) => _mutate((c) {
        final set = c.missionDone.toSet();
        if (!set.remove(slot)) set.add(slot);
        return c.copyWith(missionDone: set.toList());
      });

  Future<void> toggleExercise() =>
      _mutate((c) => c.copyWith(exerciseDone: !c.exerciseDone));
}
