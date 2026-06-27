import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/diet_rules.dart';
import '../../core/providers.dart';
import '../../data/models/meal_log.dart';
import 'meal_editor_screen.dart';
import 'meals_controller.dart';

/// 식단 기록 상세 보기. 수정/삭제 가능. 변경 시 pop(true).
class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.meal});
  final MealLog meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final time =
        '${meal.loggedAt.hour.toString().padLeft(2, '0')}:${meal.loggedAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(meal.slotLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '수정',
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => MealEditorScreen(existing: meal),
                ),
              );
              if (changed == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Chip(
                label: Text(meal.slotLabel),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Text(time, style: theme.textTheme.bodyMedium),
              const Spacer(),
              if (meal.ruleViolation == true)
                Chip(
                  label: const Text('단계 제한'),
                  backgroundColor: theme.colorScheme.errorContainer,
                  labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (meal.photos.isNotEmpty) ...[
            SizedBox(
              height: 280,
              child: PageView(
                children: [
                  for (final p in meal.photos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _SignedImage(path: p),
                    ),
                ],
              ),
            ),
            if (meal.photos.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('사진 ${meal.photos.length}장 · 좌우로 넘겨보세요',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 16),
          ],

          if (meal.foodTags.isNotEmpty) ...[
            Text('음식 태그', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in meal.foodTags)
                  Chip(
                    label: Text(FoodTags.byId(id)?.label ?? id),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if ((meal.memo ?? '').isNotEmpty) ...[
            Text('메모', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(meal.memo!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(mealsControllerProvider.notifier).delete(meal.id);
    if (context.mounted) Navigator.pop(context, true);
  }
}

class _SignedImage extends ConsumerWidget {
  const _SignedImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(supabaseServiceProvider).signedPhotoUrl(path),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.network(snap.data!,
              fit: BoxFit.cover, width: double.infinity);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
