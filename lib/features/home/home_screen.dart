import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/switchon_program.dart';
import '../../core/providers.dart';
import '../../data/models/profile.dart';

/// 홈 (P0 자리표시).
/// 시작일로부터 현재 주차/일차를 계산해 "오늘의 미션 카드"를 보여줍니다.
/// 일일 체크리스트·타이머·기록 등 본격 기능은 P1~P2에서 채웁니다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(profileProvider);
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('프로필을 불러올 수 없습니다.'));
          }
          return _Today(profile: profile);
        },
      ),
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.profile});
  final Profile profile;

  /// 시작일 기준 경과일 → 주차/일차. (정식 일시정지·재개 로직은 P1의 단계 엔진에서)
  ({int week, int day}) _position() {
    final start = profile.startDate;
    if (start == null) return (week: 1, day: 1);
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
    final clamped = days < 0 ? 0 : days;
    final week = (clamped ~/ 7 + 1).clamp(1, SwitchOnProgram.totalWeeks);
    final day = (clamped % 7 + 1);
    return (week: week, day: day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pos = _position();
    final stage = SwitchOnProgram.stageFor(pos.week, pos.day);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${pos.week}주차  ·  ${pos.day}일차',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(stage.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 20),

        // 오늘의 미션 카드
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('오늘의 미션', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                for (final m in stage.mission)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.radio_button_unchecked, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(m)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _FoodGuide(
          allowed: stage.allowedFoods,
          forbidden: stage.forbiddenFoods,
        ),

        if (stage.notes != null) ...[
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stage.notes!,
                      style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),
        Center(
          child: Text(
            '일일 체크리스트 · 단식 타이머 · 식단 기록은 곧 추가됩니다 (P1~P2)',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _FoodGuide extends StatelessWidget {
  const _FoodGuide({required this.allowed, required this.forbidden});
  final List<String> allowed;
  final List<String> forbidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 단계의 식품 가이드', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _chips(context, '허용', allowed, theme.colorScheme.primary),
            const SizedBox(height: 12),
            _chips(context, '주의·제한', forbidden, theme.colorScheme.error),
          ],
        ),
      ),
    );
  }

  Widget _chips(
      BuildContext context, String label, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: color)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in items)
              Chip(
                label: Text(i),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: color.withOpacity(0.4)),
              ),
          ],
        ),
      ],
    );
  }
}
