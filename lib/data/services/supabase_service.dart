import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/program/stage_engine.dart';
import '../models/daily_log.dart';
import '../models/fasting_session.dart';
import '../models/meal_log.dart';
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

  // --- fasting_sessions -------------------------------------------------------

  String _requireUid() {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('로그인된 사용자가 없습니다.');
    return uid;
  }

  Future<FastingSession?> fetchActiveFasting() async {
    final uid = _requireUid();
    final row = await _client
        .from('fasting_sessions')
        .select()
        .eq('user_id', uid)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return null;
    return FastingSession.fromMap(row);
  }

  Future<FastingSession> startFasting(int targetHours) async {
    final uid = _requireUid();
    final row = await _client
        .from('fasting_sessions')
        .insert({'user_id': uid, 'target_hours': targetHours})
        .select()
        .single();
    return FastingSession.fromMap(row);
  }

  Future<void> endFasting(String id, {required bool canceled}) async {
    await _client.from('fasting_sessions').update({
      'status': canceled ? 'canceled' : 'completed',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // --- meal_logs --------------------------------------------------------------

  Future<List<MealLog>> fetchTodayMeals() async {
    final uid = _requireUid();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await _client
        .from('meal_logs')
        .select()
        .eq('user_id', uid)
        .gte('logged_at', start.toUtc().toIso8601String())
        .order('logged_at', ascending: false);
    return (rows as List)
        .map((e) => MealLog.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addShake() async {
    final uid = _requireUid();
    await _client.from('meal_logs').insert({
      'user_id': uid,
      'type': 'shake',
      'shake_count': 1,
    });
  }

  Future<void> addMeal({String? memo, String? photoPath}) async {
    final uid = _requireUid();
    await _client.from('meal_logs').insert({
      'user_id': uid,
      'type': 'meal',
      if (memo != null && memo.isNotEmpty) 'memo': memo,
      if (photoPath != null && photoPath.isNotEmpty) 'photo_url': photoPath,
    });
  }

  Future<void> deleteMeal(String id) async {
    await _client.from('meal_logs').delete().eq('id', id);
  }

  // --- storage (meal-photos, 사용자 폴더 격리) ----------------------------------

  Future<String> uploadMealPhoto(Uint8List bytes, String fileName) async {
    final uid = _requireUid();
    final path = '$uid/$fileName';
    await _client.storage.from('meal-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  /// 비공개 버킷이라 표시용 서명 URL을 발급(1시간 유효).
  Future<String> signedPhotoUrl(String path) {
    return _client.storage.from('meal-photos').createSignedUrl(path, 3600);
  }
}
