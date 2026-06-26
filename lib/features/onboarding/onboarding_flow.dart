import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/program/switchon_program.dart';
import '../../core/providers.dart';
import '../../data/models/profile.dart';

/// 온보딩 3단계: 안전 고지 → 나이 게이트 → 프로그램 설정.
/// 완료 시 profiles 행을 갱신하고 게이트가 홈으로 전환합니다.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  int _step = 0;

  // 수집 값
  bool _safetyAccepted = false;
  int? _birthYear;
  DateTime _startDate = DateTime.now();
  final _goal = TextEditingController();
  bool _trackWeight = false;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  int get _age {
    final by = _birthYear;
    if (by == null) return 0;
    return DateTime.now().year - by;
  }

  bool get _underage => _birthYear != null && _age < AppConfig.minAge;

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final base = await ref.read(supabaseServiceProvider).fetchProfile();
    final profile = (base ??
            Profile(id: ref.read(supabaseServiceProvider).currentUser!.id))
        .copyWith(
      startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      currentWeek: 1,
      currentDay: 1,
      status: 'active',
      goal: _goal.text.trim().isEmpty ? null : _goal.text.trim(),
      trackWeight: _trackWeight,
      birthYear: _birthYear,
      ageVerified: true,
      safetyAcknowledgedAt: now,
      onboardingCompletedAt: now,
    );
    try {
      await ref.read(supabaseServiceProvider).upsertProfile(profile);
      ref.invalidate(profileProvider);
      // 게이트가 갱신된 프로필을 읽어 홈으로 전환합니다.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('시작하기  ${_step + 1}/3'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: switch (_step) {
          0 => _SafetyStep(
              accepted: _safetyAccepted,
              onChanged: (v) => setState(() => _safetyAccepted = v),
              onNext: _next,
            ),
          1 => _AgeGateStep(
              birthYear: _birthYear,
              underage: _underage,
              onPick: (y) => setState(() => _birthYear = y),
              onNext: _next,
            ),
          _ => _SetupStep(
              startDate: _startDate,
              goalController: _goal,
              trackWeight: _trackWeight,
              saving: _saving,
              error: _error,
              onPickDate: (d) => setState(() => _startDate = d),
              onTrackWeight: (v) => setState(() => _trackWeight = v),
              onFinish: _finish,
            ),
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 · 안전 고지 (의료 조언 아님 / 의사 상담 권고)
// ---------------------------------------------------------------------------
class _SafetyStep extends StatelessWidget {
  const _SafetyStep({
    required this.accepted,
    required this.onChanged,
    required this.onNext,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('잠깐, 먼저 읽어주세요',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              _bullet(context, Icons.medical_information_outlined,
                  '이 앱은 의료 행위나 의학적 조언을 제공하지 않습니다.'),
              _bullet(context, Icons.health_and_safety_outlined,
                  '시작 전과 진행 중에는 의사 등 전문가와 상담하세요.'),
              _bullet(context, Icons.fitness_center_outlined,
                  '근육량이 적거나 지병·복약 중이라면 단식과 식단 제한이 무리가 될 수 있습니다.'),
              _bullet(context, Icons.favorite_border,
                  '무리한 목표나 극단적 감량을 권하지 않습니다. 몸이 힘들면 언제든 멈추세요.'),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    SwitchOnProgram.medicalDisclaimer,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CheckboxListTile(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('위 내용을 이해했고, 동의합니다.'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FilledButton(
            onPressed: accepted ? onNext : null,
            child: const Text('다음'),
          ),
        ),
      ],
    );
  }

  Widget _bullet(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 · 나이 게이트 (만 19세 미만 사용 제한 안내)
// ---------------------------------------------------------------------------
class _AgeGateStep extends StatelessWidget {
  const _AgeGateStep({
    required this.birthYear,
    required this.underage,
    required this.onPick,
    required this.onNext,
  });

  final int? birthYear;
  final bool underage;
  final ValueChanged<int> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;
    final years = [for (var y = currentYear; y >= currentYear - 100; y--) y];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('출생연도를 알려주세요',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '안전을 위해 만 ${AppConfig.minAge}세 미만은 보호자·전문가 상담 후 이용을 권장합니다.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                value: birthYear,
                decoration: const InputDecoration(labelText: '출생연도'),
                items: [
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text('$y년')),
                ],
                onChanged: (y) {
                  if (y != null) onPick(y);
                },
              ),
              if (underage) ...[
                const SizedBox(height: 24),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '만 ${AppConfig.minAge}세 미만은 성장기 영양이 특히 중요합니다. '
                            '단식·식단 제한 프로그램은 보호자와 의사의 판단 아래에서만 '
                            '진행하시길 권장하며, 지금은 앱 사용을 권하지 않습니다.',
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FilledButton(
            onPressed: (birthYear != null && !underage) ? onNext : null,
            child: const Text('다음'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 · 프로그램 설정 (시작일 / 선택적 목표 / 체중 추적 옵션)
// ---------------------------------------------------------------------------
class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.startDate,
    required this.goalController,
    required this.trackWeight,
    required this.saving,
    required this.error,
    required this.onPickDate,
    required this.onTrackWeight,
    required this.onFinish,
  });

  final DateTime startDate;
  final TextEditingController goalController;
  final bool trackWeight;
  final bool saving;
  final String? error;
  final ValueChanged<DateTime> onPickDate;
  final ValueChanged<bool> onTrackWeight;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = startDate;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('프로그램을 시작해요', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('시작일'),
                subtitle: Text('${d.year}.${d.month}.${d.day}'),
                trailing: TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: now.subtract(const Duration(days: 14)),
                      lastDate: now.add(const Duration(days: 30)),
                    );
                    if (picked != null) onPickDate(picked);
                  },
                  child: const Text('변경'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: goalController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '나의 다짐 (선택)',
                  hintText: '예: 컨디션 좋게, 끝까지 완주하기',
                  helperText: '숫자 목표가 아니어도 좋아요. 비워둬도 됩니다.',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: trackWeight,
                onChanged: onTrackWeight,
                title: const Text('체중도 기록할게요 (선택)'),
                subtitle: const Text('체중 입력은 선택사항이에요. 끄면 숫자에 신경 쓰지 않고 진행해요.'),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FilledButton(
            onPressed: saving ? null : onFinish,
            child: saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('시작하기'),
          ),
        ),
      ],
    );
  }
}
