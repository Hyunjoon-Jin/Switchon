import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Supabase 접근 래퍼 (auth + profiles).
/// P1~P2에서 daily_logs / meal_logs / progress 메서드를 여기에 확장합니다.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  // --- profiles ---------------------------------------------------------------

  Future<Profile?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  Future<Profile> upsertProfile(Profile profile) async {
    final uid = currentUser?.id;
    if (uid == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }
    final payload = {'id': uid, ...profile.toUpdateMap()};
    final row =
        await _client.from('profiles').upsert(payload).select().single();
    return Profile.fromMap(row);
  }
}
