import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'reminder_service.dart';

/// 알림 설정 화면 — 셰이크/물/취침 마감 반복 리마인더.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  ReminderSettings? _settings;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(reminderServiceProvider).load();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _update(ReminderSettings next) async {
    final enablingSomething =
        next.shakeEnabled || next.waterEnabled || next.bedtimeEnabled;
    setState(() {
      _settings = next;
      _busy = true;
    });
    final service = ref.read(reminderServiceProvider);
    try {
      if (enablingSomething) {
        // 알림을 켤 때 권한 요청(이미 허용돼 있으면 즉시 통과).
        await ref.read(notificationServiceProvider).requestPermissions();
      }
      await service.save(next);
      await service.apply(next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (_busy) const LinearProgressIndicator(),
                SwitchListTile(
                  title: const Text('셰이크 알림'),
                  subtitle: const Text('08·12·16·20시'),
                  value: s.shakeEnabled,
                  onChanged: (v) =>
                      _update(s.copyWith(shakeEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text('물 마시기 알림'),
                  subtitle: const Text('10·14·18시'),
                  value: s.waterEnabled,
                  onChanged: (v) =>
                      _update(s.copyWith(waterEnabled: v)),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('취침 4시간 전 식사 마감'),
                  subtitle: Text(
                    '취침 ${_hm(s.bedtimeHour, s.bedtimeMinute)} → '
                    '알림 ${_hm((s.bedtimeHour - 4 + 24) % 24, s.bedtimeMinute)}',
                  ),
                  value: s.bedtimeEnabled,
                  onChanged: (v) =>
                      _update(s.copyWith(bedtimeEnabled: v)),
                ),
                ListTile(
                  enabled: s.bedtimeEnabled,
                  title: const Text('취침 시각'),
                  trailing: Text(_hm(s.bedtimeHour, s.bedtimeMinute)),
                  onTap: s.bedtimeEnabled
                      ? () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                                hour: s.bedtimeHour, minute: s.bedtimeMinute),
                          );
                          if (picked != null) {
                            await _update(s.copyWith(
                              bedtimeHour: picked.hour,
                              bedtimeMinute: picked.minute,
                            ));
                          }
                        }
                      : null,
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '알림이 오지 않으면 기기 설정에서 앱 알림 권한을 확인해 주세요. '
                    '단식 종료 알림은 단식 시작 시 자동으로 예약됩니다.',
                  ),
                ),
              ],
            ),
    );
  }

  String _hm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
