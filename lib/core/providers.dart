import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/profile.dart';
import '../data/services/auth_service.dart';
import '../data/services/supabase_service.dart';
import '../services/notification_service.dart';
import 'program/stage_engine.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(ref.watch(supabaseClientProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// 인증 상태 스트림 — 로그인/로그아웃에 따라 라우팅 게이트가 반응.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseServiceProvider).authChanges;
});

/// 현재 로그인 사용자의 프로필. 온보딩 게이트가 이 값으로 분기.
final profileProvider = FutureProvider<Profile?>((ref) async {
  // 인증 상태가 바뀌면 프로필을 다시 읽도록 의존.
  ref.watch(authStateProvider);
  final service = ref.watch(supabaseServiceProvider);
  if (!service.isSignedIn) return null;
  return service.fetchProfile();
});

/// 현재 단계 위치(주차/일차/규칙). 프로필이 없거나 시작 전이면 null.
final currentStagePositionProvider = Provider<StagePosition?>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  final start = profile?.startDate;
  if (profile == null || start == null) return null;
  return StageEngine.compute(
    startDate: start,
    status: profile.status,
    pausedAt: profile.pausedAt,
    today: DateTime.now(),
  );
});

/// 주차 점검이 가능한 주차 번호(주 마지막 날 + 아직 점검 안 함) 또는 null.
final weeklyCheckDueProvider = FutureProvider<int?>((ref) async {
  final pos = ref.watch(currentStagePositionProvider);
  if (pos == null || pos.isPaused) return null;
  if (pos.day != 7) return null; // 주 마지막 날에만 노출
  final existing =
      await ref.watch(supabaseServiceProvider).fetchWeekProgress(pos.week);
  if (existing != null && existing.isChecked) return null;
  return pos.week;
});
