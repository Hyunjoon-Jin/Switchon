import 'package:flutter/material.dart';

/// 오늘의 미션 카드 (단계별 권장 행동 목록).
class MissionCard extends StatelessWidget {
  const MissionCard({super.key, required this.mission});
  final List<String> mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('오늘의 미션', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final m in mission)
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
    );
  }
}
