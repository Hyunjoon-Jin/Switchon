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

  Future<void> addWater(int ml) => _mutate(
        (c) => c.copyWith(
          waterMl: (c.waterMl + ml).clamp(0, 100000).toInt(),
        ),
      );

  /// 잠든/일어난 시각을 설정하고(부분 가능) 수면 시간을 자동 계산.
  Future<void> setSleepTimes({int? startMinutes, int? endMinutes}) =>
      _mutate((c) {
        final start = startMinutes ?? c.sleepStartMinutes;
        final end = endMinutes ?? c.sleepEndMinutes;
        final hours = (start != null && end != null)
            ? DailyLog.durationHours(start, end)
            : c.sleepHours;
        return c.copyWith(
          sleepStartMinutes: start,
          sleepEndMinutes: end,
          sleepHours: hours,
        );
      });

  Future<void> toggleFasting() =>
      _mutate((c) => c.copyWith(fastingDone: !c.fastingDone));

  /// 오늘의 미션 항목(라벨) 체크 토글.
  Future<void> toggleMission(String label) => _mutate((c) {
        final set = c.missionDone.toSet();
        if (!set.remove(label)) set.add(label);
        return c.copyWith(missionDone: set.toList());
      });

  /// 자동 체크된 미션을 저장합니다 (이미 체크된 경우 무시).
  Future<void> setMissionChecked(String label) => _mutate((c) {
        final set = c.missionDone.toSet()..add(label);
        return c.copyWith(missionDone: set.toList());
      });

  Future<void> toggleExercise() =>
      _mutate((c) => c.copyWith(exerciseDone: !c.exerciseDone));
}
