import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/recovery_engine.dart';
import '../../core/providers.dart';
import '../../data/models/recovery.dart';

/// 이번 세션에서 닫은 회복 신호 키 모음(중복 노출 방지).
final dismissedRecoveryProvider =
    StateProvider<Set<String>>((_) => <String>{});

/// 최근 기록을 모아 회복 신호를 산출. 신호 없으면 null.
final recoverySignalProvider = FutureProvider<RecoverySignal?>((ref) async {
  ref.watch(authStateProvider);
  final service = ref.watch(supabaseServiceProvider);
  if (!service.isSignedIn) return null;

  final logs = await service.fetchRecentDailyLogs(7);
  final meals = await service.fetchAllMeals();
  final fastings = await service.fetchAllFastings();

  return RecoveryEngine.detect(
    today: DateTime.now(),
    recentLogs: logs,
    recentMeals: meals,
    recentFastings: fastings,
  );
});
