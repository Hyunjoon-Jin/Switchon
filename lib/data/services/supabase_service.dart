import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/program/stage_engine.dart';
import '../models/daily_log.dart';
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

  Future<Profile> _patchProfile(Map<String, dynamic> patch) async {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('로그인된 사용자가 없습니다.');
    final row = await _client
        .from('profiles')
        .update(patch)
        .eq('id', uid)
        .select()
        .single();
    return Profile.fromMap(row);
  }

  // --- 프로그램 상태 (일시정지 / 재개 / 완료) -----------------------------------

  Future<Profile> pauseProgram(DateTime today) {
    final date = DailyLog.dateOnly(today).toIso8601String().split('T').first;
    return _patchProfile({'status': 'paused', 'paused_at': date});
  }

  /// 재개: 멈춰 있던 기간만큼 start_date 를 뒤로 밀고 paused_at 을 비웁니다.
  Future<Profile> resumeProgram(Profile profile, DateTime today) {
    final start = profile.startDate;
    final pausedAt = profile.pausedAt;
    if (start == null || pausedAt == null) {
      return _patchProfile({'status': 'active', 'paused_at': null});
    }
    final newStart = StageEngine.resumedStartDate(
      startDate: start,
      pausedAt: pausedAt,
      today: today,
    );
    return _patchProfile({
      'status': 'active',
      'paused_at': null,
      'start_date': newStart.toIso8601String().split('T').first,
    });
  }

  Future<Profile> completeProgram() {
    return _patchProfile({'status': 'completed', 'paused_at': null});
  }

  // --- daily_logs -------------------------------------------------------------

  Future<DailyLog> fetchDailyLog(DateTime date) async {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('로그인된 사용자가 없습니다.');
    final d = DailyLog.dateOnly(date).toIso8601String().split('T').first;
    final row = await _client
        .from('daily_logs')
        .select()
        .eq('user_id', uid)
        .eq('log_date', d)
        .maybeSingle();
    if (row == null) return DailyLog.empty(date);
    return DailyLog.fromMap(row);
  }

  Future<DailyLog> saveDailyLog(DailyLog log) async {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('로그인된 사용자가 없습니다.');
    final row = await _client
        .from('daily_logs')
        .upsert(log.toUpsertMap(uid), onConflict: 'user_id,log_date')
        .select()
        .single();
    return DailyLog.fromMap(row);
  }
}
