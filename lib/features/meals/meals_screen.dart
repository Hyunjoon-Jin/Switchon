import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../data/models/meal_log.dart';
import 'meals_controller.dart';

/// 식단 기록 화면 — 셰이크 카운터 + 식사 사진/메모.
class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 기록')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddMeal(context, ref),
        icon: const Icon(Icons.restaurant_outlined),
        label: const Text('식사 기록'),
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (logs) {
          final shakes = shakeCountOf(logs);
          final meals = logs.where((m) => !m.isShake).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ShakeCounter(
                count: shakes,
                onAdd: () =>
                    ref.read(mealsControllerProvider.notifier).addShake(),
              ),
              const SizedBox(height: 20),
              Text('식사 (${meals.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (meals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('아직 기록한 식사가 없어요.')),
                )
              else
                for (final m in meals)
                  _MealTile(
                    meal: m,
                    onDelete: () => ref
                        .read(mealsControllerProvider.notifier)
                        .delete(m.id),
                  ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddMeal(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddMealSheet(),
    );
  }
}

class _ShakeCounter extends StatelessWidget {
  const _ShakeCounter({required this.count, required this.onAdd});
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.local_drink_outlined,
                size: 36, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('단백질 셰이크', style: theme.textTheme.titleMedium),
                  Text('오늘 $count회',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('1회'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealTile extends ConsumerWidget {
  const _MealTile({required this.meal, required this.onDelete});
  final MealLog meal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final time =
        '${meal.loggedAt.hour.toString().padLeft(2, '0')}:${meal.loggedAt.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meal.hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _Thumb(path: meal.photoPath),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    meal.memo?.isNotEmpty == true ? meal.memo! : '식사',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(supabaseServiceProvider).signedPhotoUrl(path),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.network(
            snap.data!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          );
        }
        return const SizedBox(
          width: 56,
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}

/// 식사 기록 입력 시트 — 메모 + 선택적 사진.
class _AddMealSheet extends ConsumerStatefulWidget {
  const _AddMealSheet();

  @override
  ConsumerState<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<_AddMealSheet> {
  final _memo = TextEditingController();
  XFile? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file != null) setState(() => _picked = file);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final service = ref.read(supabaseServiceProvider);
    try {
      String? photoPath;
      if (_picked != null) {
        final bytes = await _picked!.readAsBytes();
        final name =
            'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
        photoPath = await service.uploadMealPhoto(bytes, name);
      }
      await ref.read(mealsControllerProvider.notifier).addMeal(
            memo: _memo.text.trim(),
            photoPath: photoPath,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('식사 기록', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pick,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_picked == null ? '사진 추가 (선택)' : '사진 선택됨 ✓'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memo,
            maxLength: 140,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              hintText: '무엇을 드셨나요?',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
