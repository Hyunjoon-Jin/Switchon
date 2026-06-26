import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../services/notification_service.dart';

/// 반복 리마인더 설정 (로컬 저장). 셰이크/물은 고정 시간대, 취침 마감은 사용자 지정.
class ReminderSettings {
  const ReminderSettings({
    this.shakeEnabled = false,
    this.waterEnabled = false,
    this.bedtimeEnabled = false,
    this.bedtimeHour = 23,
    this.bedtimeMinute = 0,
  });

  final bool shakeEnabled;
  final bool waterEnabled;
  final bool bedtimeEnabled;
  final int bedtimeHour;
  final int bedtimeMinute;

  ReminderSettings copyWith({
    bool? shakeEnabled,
    bool? waterEnabled,
    bool? bedtimeEnabled,
    int? bedtimeHour,
    int? bedtimeMinute,
  }) {
    return ReminderSettings(
      shakeEnabled: shakeEnabled ?? this.shakeEnabled,
      waterEnabled: waterEnabled ?? this.waterEnabled,
      bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
      bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
    );
  }
}

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref.watch(notificationServiceProvider));
});

class ReminderService {
  ReminderService(this._notif);

  final NotificationService _notif;

  // 고정 시간대 (시, 분)
  static const List<(int, int)> shakeTimes = [(8, 0), (12, 0), (16, 0), (20, 0)];
  static const List<(int, int)> waterTimes = [(10, 0), (14, 0), (18, 0)];

  static const _kShake = 'rem_shake';
  static const _kWater = 'rem_water';
  static const _kBedtime = 'rem_bedtime';
  static const _kBedH = 'rem_bed_h';
  static const _kBedM = 'rem_bed_m';

  Future<ReminderSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return ReminderSettings(
      shakeEnabled: p.getBool(_kShake) ?? false,
      waterEnabled: p.getBool(_kWater) ?? false,
      bedtimeEnabled: p.getBool(_kBedtime) ?? false,
      bedtimeHour: p.getInt(_kBedH) ?? 23,
      bedtimeMinute: p.getInt(_kBedM) ?? 0,
    );
  }

  Future<void> save(ReminderSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kShake, s.shakeEnabled);
    await p.setBool(_kWater, s.waterEnabled);
    await p.setBool(_kBedtime, s.bedtimeEnabled);
    await p.setInt(_kBedH, s.bedtimeHour);
    await p.setInt(_kBedM, s.bedtimeMinute);
  }

  /// 설정에 맞춰 모든 반복 알림을 다시 예약.
  Future<void> apply(ReminderSettings s) async {
    await _notif.init();

    // 셰이크
    for (var i = 0; i < shakeTimes.length; i++) {
      final id = NotificationService.idShakeBase + i;
      if (s.shakeEnabled) {
        await _notif.scheduleDaily(
          id: id,
          hour: shakeTimes[i].$1,
          minute: shakeTimes[i].$2,
          title: '셰이크 시간이에요 🥤',
          body: '단백질 셰이크 한 잔 어떠세요?',
        );
      } else {
        await _notif.cancel(id);
      }
    }

    // 물
    for (var i = 0; i < waterTimes.length; i++) {
      final id = NotificationService.idWaterBase + i;
      if (s.waterEnabled) {
        await _notif.scheduleDaily(
          id: id,
          hour: waterTimes[i].$1,
          minute: waterTimes[i].$2,
          title: '물 마실 시간 💧',
          body: '하루 2L, 천천히 채워가요.',
        );
      } else {
        await _notif.cancel(id);
      }
    }

    // 취침 4시간 전 식사 마감
    if (s.bedtimeEnabled) {
      // 취침 4시간 전. 자정을 넘으면 전날로 되돌려 시(hour)만 보정(매일 반복).
      final h = (s.bedtimeHour - 4 + 24) % 24;
      await _notif.scheduleDaily(
        id: NotificationService.idBedtime,
        hour: h,
        minute: s.bedtimeMinute,
        title: '식사 마감 시간 🌙',
        body: '취침 4시간 전이에요. 이후엔 음식 섭취를 마쳐요.',
      );
    } else {
      await _notif.cancel(NotificationService.idBedtime);
    }
  }
}
