import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/program/stage_engine.dart';
import '../models/daily_log.dart';
import '../models/fasting_session.dart';
import '../models/meal_log.dart';
import '../models/profile.dart';
import '../models/progress.dart';

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

  // --- progress (주차 점검 / 분기) ----------------------------------------------

  Future<WeekProgress?> fetchWeekProgress(int weekNo) async {
    final uid = _requireUid();
    final row = await _client
        .from('progress')
        .select()
        .eq('user_id', uid)
        .eq('week_no', weekNo)
        .maybeSingle();
    if (row == null) return null;
    return WeekProgress.fromMap(row);
  }

  Future<WeekProgress> saveWeekCheck({
    required int weekNo,
    required String stage,
    String? branchResult,
  }) async {
    final uid = _requireUid();
    final row = await _client
        .from('progress')
        .upsert({
          'user_id': uid,
          'week_no': weekNo,
          'stage': stage,
          if (branchResult != null) 'branch_result': branchResult,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,week_no')
        .select()
        .single();
    return WeekProgress.fromMap(row);
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

  /// 최근 [days] 일의 일일 로그(날짜 오름차순).
  Future<List<DailyLog>> fetchRecentDailyLogs(int days) async {
    final uid = _requireUid();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final fromStr = from.toIso8601String().split('T').first;
    final rows = await _client
        .from('daily_logs')
        .select()
        .eq('user_id', uid)
        .gte('log_date', fromStr)
        .order('log_date', ascending: true);
    return (rows as List)
        .map((e) => DailyLog.fromMap(e as Map<String, dynamic>))
        .toList();
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

  /// 전체 단식 세션(통계용).
  Future<List<FastingSession>> fetchAllFastings() async {
    final uid = _requireUid();
    final rows = await _client
        .from('fasting_sessions')
        .select()
        .eq('user_id', uid)
        .order('started_at', ascending: false);
    return (rows as List)
        .map((e) => FastingSession.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> endFasting(String id, {required bool canceled}) async {
    await _client.from('fasting_sessions').update({
      'status': canceled ? 'canceled' : 'completed',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // --- meal_logs --------------------------------------------------------------

  Future<List<MealLog>> fetchTodayMeals() => fetchMealsForDate(DateTime.now());

  /// 특정 날짜의 식단 기록(끼니 순 → 시간 순).
  Future<List<MealLog>> fetchMealsForDate(DateTime date) async {
    final uid = _requireUid();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _client
        .from('meal_logs')
        .select()
        .eq('user_id', uid)
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String())
        .order('logged_at', ascending: true);
    return (rows as List)
        .map((e) => MealLog.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// 전체 식단 기록(통계용 — 셰이크 누적·위반 집계).
  Future<List<MealLog>> fetchAllMeals() async {
    final uid = _requireUid();
    final rows = await _client
        .from('meal_logs')
        .select()
        .eq('user_id', uid)
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

  Future<void> addMeal({
    String? mealSlot,
    String? memo,
    List<String> photoUrls = const [],
    DateTime? loggedAt,
    List<String> foodTags = const [],
    bool? ruleViolation,
    AiAnalysis? ai,
  }) async {
    final uid = _requireUid();
    await _client.from('meal_logs').insert({
      'user_id': uid,
      'type': 'meal',
      if (mealSlot != null) 'meal_slot': mealSlot,
      if (memo != null && memo.isNotEmpty) 'memo': memo,
      'photo_urls': photoUrls,
      if (loggedAt != null) 'logged_at': loggedAt.toUtc().toIso8601String(),
      'food_tags': foodTags,
      // AI 가 위반 판정했으면 그 값을 우선, 아니면 규칙엔진 결과.
      if (ai != null || ruleViolation != null)
        'rule_violation': ai != null ? ai.isViolation : ruleViolation,
      if (ai != null) ...ai.toColumns(),
    });
  }

  /// 기존 식단 기록 수정.
  Future<void> updateMeal(
    String id, {
    String? mealSlot,
    String? memo,
    List<String>? photoUrls,
    DateTime? loggedAt,
    List<String>? foodTags,
    bool? ruleViolation,
    AiAnalysis? ai,
  }) async {
    await _client.from('meal_logs').update({
      'meal_slot': mealSlot,
      'memo': (memo != null && memo.isEmpty) ? null : memo,
      if (photoUrls != null) 'photo_urls': photoUrls,
      if (loggedAt != null) 'logged_at': loggedAt.toUtc().toIso8601String(),
      if (foodTags != null) 'food_tags': foodTags,
      'rule_violation': ai != null ? ai.isViolation : ruleViolation,
      if (ai != null) ...ai.toColumns(),
    }).eq('id', id);
  }

  Future<void> deleteMeal(String id) async {
    await _client.from('meal_logs').delete().eq('id', id);
  }

  // --- AI 식단 판독 (Edge Function: analyze-meal) ------------------------------

  /// 식사 사진을 Claude(비전)로 분석한다. API 키는 Edge Function 에만 있으므로
  /// 클라이언트는 식사 id + 현재 단계 컨텍스트만 보낸다. 함수가 스토리지에서
  /// 사진을 직접 읽어 분석하고, 결과를 meal_logs 에 기록한 뒤 JSON 을 돌려준다.
  ///
  /// [verdict == 'violation'] 이면 함수가 rule_violation 도 true 로 덮어쓴다(②B).
  Future<AiAnalysis> analyzeMeal({
    required String mealId,
    required int week,
    required int day,
    required String stageTitle,
    required List<String> allowedFoods,
    required List<String> forbiddenFoods,
    required String mealPlan,
  }) async {
    _requireUid();
    final res = await _client.functions.invoke(
      'analyze-meal',
      body: {
        'meal_id': mealId,
        'week': week,
        'day': day,
        'stage_title': stageTitle,
        'allowed_foods': allowedFoods,
        'forbidden_foods': forbiddenFoods,
        'meal_plan': mealPlan,
      },
    );
    return _parseAnalysis(res.data);
  }

  /// 저장 전(편집 화면) 즉시 분석. 사진 바이트(+메뉴 텍스트)를 인라인으로 보낸다.
  /// 결과는 DB 에 기록하지 않고 반환만 하며, 저장 시 [addMeal]/[updateMeal] 의
  /// `ai` 인자로 함께 저장한다.
  Future<AiAnalysis> analyzeMealInline({
    required List<Uint8List> images,
    String? memo,
    required int week,
    required int day,
    required String stageTitle,
    required List<String> allowedFoods,
    required List<String> forbiddenFoods,
    required String mealPlan,
  }) async {
    _requireUid();
    final encoded = images
        .map((b) => {'media_type': 'image/jpeg', 'data': base64Encode(b)})
        .toList();
    final res = await _client.functions.invoke(
      'analyze-meal',
      body: {
        'images': encoded,
        if (memo != null && memo.isNotEmpty) 'memo': memo,
        'week': week,
        'day': day,
        'stage_title': stageTitle,
        'allowed_foods': allowedFoods,
        'forbidden_foods': forbiddenFoods,
        'meal_plan': mealPlan,
      },
    );
    return _parseAnalysis(res.data);
  }

  AiAnalysis _parseAnalysis(dynamic data) {
    if (data is! Map) {
      throw StateError('AI 분석 응답을 해석하지 못했어요.');
    }
    if (data['error'] != null) {
      throw StateError(data['error'].toString());
    }
    return AiAnalysis.fromMap(Map<String, dynamic>.from(data));
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
