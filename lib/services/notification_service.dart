import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 알림 서비스 — 단식 종료 / 셰이크 / 물 / 취침 4h 전 마감 리마인더.
///
/// 원격 푸시(서버)는 3차 커뮤니티에서 도입 예정. MVP는 전부 기기 내 예약 알림.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // 알림 ID 네임스페이스 (겹치지 않게 고정)
  static const int idFastingEnd = 1001;
  static const int idWaterBase = 2000; // 2000~2099
  static const int idShakeBase = 2100; // 2100~2199
  static const int idBedtime = 2200;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'switchon_reminders',
    '스위치온 리마인더',
    channelDescription: '단식·셰이크·물·취침 알림',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb) return; // 웹은 로컬 알림 미지원 — 조용히 건너뜀
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // 실패 시 기본(UTC) 유지 — 절대시각 알림(단식 종료)은 여전히 정확.
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  /// 알림 권한 요청 (iOS / Android 13+).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // --- 단식 종료 알림 (절대 시각) ----------------------------------------------

  Future<void> scheduleFastingEnd(DateTime endTime, int targetHours) async {
    if (kIsWeb) return;
    await init();
    final when = tz.TZDateTime.from(endTime, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      idFastingEnd,
      '단식 완료! 🎉',
      '$targetHours시간 단식을 마쳤어요. 잘하셨어요.',
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelFastingEnd() =>
      kIsWeb ? Future.value() : _plugin.cancel(idFastingEnd);

  // --- 반복 일일 리마인더 (매일 같은 시각) --------------------------------------

  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
    );
  }

  Future<void> cancel(int id) =>
      kIsWeb ? Future.value() : _plugin.cancel(id);
  Future<void> cancelAll() =>
      kIsWeb ? Future.value() : _plugin.cancelAll();

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
