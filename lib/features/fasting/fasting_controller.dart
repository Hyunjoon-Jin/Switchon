import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/fasting_session.dart';

/// 활성 단식 세션 컨트롤러. null = 진행 중인 단식 없음.
final fastingControllerProvider =
    AsyncNotifierProvider<FastingController, FastingSession?>(
        FastingController.new);

class FastingController extends AsyncNotifier<FastingSession?> {
  @override
  Future<FastingSession?> build() {
    ref.watch(authStateProvider);
    return ref.watch(supabaseServiceProvider).fetchActiveFasting();
  }

  Future<void> start(int targetHours) async {
    final service = ref.read(supabaseServiceProvider);
    state = const AsyncLoading();
    try {
      final session = await service.startFasting(targetHours);
      // 단식 종료 시각에 로컬 알림 예약.
      await ref
          .read(notificationServiceProvider)
          .scheduleFastingEnd(session.targetEnd, targetHours);
      state = AsyncData(session);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> stop({required bool canceled}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final service = ref.read(supabaseServiceProvider);
    await service.endFasting(current.id, canceled: canceled);
    await ref.read(notificationServiceProvider).cancelFastingEnd();
    state = const AsyncData(null);
  }
}
