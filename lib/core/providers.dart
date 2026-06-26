import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/profile.dart';
import '../data/services/auth_service.dart';
import '../data/services/supabase_service.dart';
import '../services/notification_service.dart';

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
