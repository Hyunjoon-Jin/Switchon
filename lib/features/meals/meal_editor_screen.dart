import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/program/diet_rules.dart';
import '../../core/program/switchon_program.dart';
import '../../core/providers.dart';
import '../../data/models/meal_log.dart';
import 'meals_controller.dart';
import 'widgets/ai_result_card.dart';

const int kMaxMealPhotos = 4;

/// 식단 기록 추가/수정 화면.
class MealEditorScreen extends ConsumerStatefulWidget {
  const MealEditorScreen({super.key, this.existing, this.initialSlot});

  /// null 이면 새 기록, 있으면 수정.
  final MealLog? existing;

  /// 새 기록일 때 미리 선택할 끼니 슬롯(아침/점심/간식/저녁).
  final String? initialSlot;

  @override
  ConsumerState<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends ConsumerState<MealEditorScreen> {
  late final TextEditingController _memo;
  late DateTime _loggedAt;
  String? _slot;
  final Set<String> _tags = {};
  final List<String> _existingPaths = []; // 이미 저장된 사진 경로
  final List<XFile> _newFiles = []; // 새로 추가한 사진
  bool _saving = false;
  AiAnalysis? _ai; // 저장 전 분석 결과(저장 시 함께 기록)
  bool _analyzing = false;

  bool get _isEdit => widget.existing != null;
  int get _photoCount => _existingPaths.length + _newFiles.length;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _memo = TextEditingController(text: e?.memo ?? '');
    _loggedAt = e?.loggedAt ?? DateTime.now();
    _slot = e?.mealSlot ?? widget.initialSlot ?? _guessSlot(_loggedAt);
    if (e != null) {
      _tags.addAll(e.foodTags);
      _existingPaths.addAll(e.photos);
      _ai = e.ai;
    }
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  static String _guessSlot(DateTime t) {
    final h = t.hour;
    if (h < 11) return MealSlot.breakfast.id;
    if (h < 15) return MealSlot.lunch.id;
    if (h < 21) return MealSlot.dinner.id;
    return MealSlot.snack.id;
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (picked != null) {
      setState(() => _loggedAt = DateTime(_loggedAt.year, _loggedAt.month,
          _loggedAt.day, picked.hour, picked.minute));
    }
  }

  Future<void> _addPhotos() async {
    final remaining = kMaxMealPhotos - _photoCount;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (picked.isEmpty) return;
    setState(() => _newFiles.addAll(picked.take(remaining)));
  }

  String _planText(MealPlan plan) => [
        '셰이크: ${plan.shake}',
        if (plan.lunch != null) '점심: ${plan.lunch}',
        if (plan.dinner != null) '저녁: ${plan.dinner}',
        if (plan.snack != null) '간식: ${plan.snack}',
        if (plan.fruit != null) '과일: ${plan.fruit}',
      ].join(' / ');

  /// 저장 전 즉시 AI 분석 — 새로 고른 사진(+메모)을 인라인으로 보낸다.
  Future<void> _analyze() async {
    final bytesList = <Uint8List>[];
    for (final f in _newFiles) {
      bytesList.add(await f.readAsBytes());
    }
    final memo = _memo.text.trim();
    if (bytesList.isEmpty && memo.isEmpty) {
      _snack('사진을 추가하거나 메뉴(메모)를 입력해 주세요.');
      return;
    }
    setState(() => _analyzing = true);
    try {
      final pos = ref.read(currentStagePositionProvider);
      final stage = pos?.stage ?? SwitchOnProgram.stages.first;
      final result =
          await ref.read(supabaseServiceProvider).analyzeMealInline(
                images: bytesList,
                memo: memo,
                week: pos?.week ?? 1,
                day: pos?.day ?? 1,
                stageTitle: stage.title,
                allowedFoods: stage.allowedFoods,
                forbiddenFoods: stage.forbiddenFoods,
                mealPlan: _planText(stage.mealPlan),
              );
      if (!mounted) return;
      setState(() {
        _ai = result;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      final detail = e is StateError ? e.message : e.toString();
      _snack('AI 분석 실패: $detail');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  RuleEvaluation? _evaluate() {
    final pos = ref.read(currentStagePositionProvider);
    if (pos == null) return null;
    return DietRules.evaluate(
      stageId: pos.stage.id,
      week: pos.week,
      tagIds: _tags.toList(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final service = ref.read(supabaseServiceProvider);
    final controller = ref.read(mealsControllerProvider.notifier);
    final eval = _evaluate();
    try {
      // 새 사진 업로드 → 경로 수집
      final uploaded = <String>[];
      for (var i = 0; i < _newFiles.length; i++) {
        final bytes = await _newFiles[i].readAsBytes();
        final name =
            'meal_${_loggedAt.millisecondsSinceEpoch}_$i.jpg';
        uploaded.add(await service.uploadMealPhoto(bytes, name));
      }
      final photoUrls = [..._existingPaths, ...uploaded];

      if (_isEdit) {
        await controller.updateMeal(
          widget.existing!.id,
          mealSlot: _slot,
          memo: _memo.text.trim(),
          photoUrls: photoUrls,
          loggedAt: _loggedAt,
          foodTags: _tags.toList(),
          ruleViolation: eval?.isViolation,
          ai: _ai,
        );
      } else {
        await controller.addMeal(
          mealSlot: _slot,
          memo: _memo.text.trim(),
          photoUrls: photoUrls,
          loggedAt: _loggedAt,
          foodTags: _tags.toList(),
          ruleViolation: eval?.isViolation,
          ai: _ai,
        );
      }
      if (mounted) Navigator.pop(context, true);
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
    final theme = Theme.of(context);
    final eval = _evaluate();
    final pos = ref.watch(currentStagePositionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '식사 수정' : '식사 기록')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 끼니 + 시간
          Text('끼니', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in MealSlot.all)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _slot == s.id,
                  onSelected: (_) => setState(() => _slot = s.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('시간'),
            trailing: TextButton(
              onPressed: _pickTime,
              child: Text(_fmtTime(_loggedAt)),
            ),
          ),
          const Divider(height: 24),

          // 사진
          Text('사진 ($_photoCount/$kMaxMealPhotos)',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _PhotoStrip(
            existingPaths: _existingPaths,
            newFiles: _newFiles,
            onAdd: _photoCount < kMaxMealPhotos ? _addPhotos : null,
            onRemoveExisting: (p) => setState(() => _existingPaths.remove(p)),
            onRemoveNew: (f) => setState(() => _newFiles.remove(f)),
          ),
          const Divider(height: 24),

          // 끼니별 가이드 힌트
          if (pos != null) ...[
            Text('현재 ${pos.week}주차 — 허용: '
                '${pos.stage.allowedFoods.take(3).join(", ")} 등',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
          ],

          // 태그
          Text('무엇을 드셨나요? (태그)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in FoodTags.all)
                FilterChip(
                  label: Text(tag.label),
                  selected: _tags.contains(tag.id),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _tags.add(tag.id);
                    } else {
                      _tags.remove(tag.id);
                    }
                  }),
                ),
            ],
          ),
          if (eval != null && !eval.isClean) ...[
            const SizedBox(height: 12),
            _RuleBanner(eval: eval),
          ],
          const SizedBox(height: 16),

          // 메모
          TextField(
            controller: _memo,
            maxLength: 500,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              hintText: '먹은 음식·양·느낌 등을 자세히 적어보세요',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // AI 분석 (저장 전 즉시) — 점수·피드백·칼로리/영양 추정
          OutlinedButton.icon(
            onPressed: _analyzing ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_analyzing
                ? 'AI가 분석 중…'
                : (_ai == null ? 'AI 분석 (점수·칼로리·영양)' : 'AI 다시 분석')),
          ),
          if (_ai != null) ...[
            const SizedBox(height: 12),
            AiResultCard(analysis: _ai!),
          ],
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? '수정 저장' : '저장'),
          ),
        ],
      ),
    );
  }
}

/// 사진 가로 스트립 (기존 경로 + 새 파일 + 추가 버튼).
class _PhotoStrip extends ConsumerWidget {
  const _PhotoStrip({
    required this.existingPaths,
    required this.newFiles,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  final List<String> existingPaths;
  final List<XFile> newFiles;
  final VoidCallback? onAdd;
  final ValueChanged<String> onRemoveExisting;
  final ValueChanged<XFile> onRemoveNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final p in existingPaths)
            _thumb(
              context,
              child: _SignedImage(path: p),
              onRemove: () => onRemoveExisting(p),
            ),
          for (final f in newFiles)
            _thumb(
              context,
              child: FutureBuilder<Uint8List>(
                future: f.readAsBytes(),
                builder: (_, snap) => snap.hasData
                    ? Image.memory(snap.data!, fit: BoxFit.cover)
                    : const ColoredBox(color: Color(0x11000000)),
              ),
              onRemove: () => onRemoveNew(f),
            ),
          if (onAdd != null)
            InkWell(
              onTap: onAdd,
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_a_photo_outlined),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context,
      {required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(right: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: child,
        ),
        Positioned(
          right: 4,
          top: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 11,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// 비공개 버킷 경로 → 서명 URL 이미지.
class _SignedImage extends ConsumerWidget {
  const _SignedImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(supabaseServiceProvider).signedPhotoUrl(path),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.network(snap.data!, fit: BoxFit.cover);
        }
        return const ColoredBox(color: Color(0x11000000));
      },
    );
  }
}

class _RuleBanner extends StatelessWidget {
  const _RuleBanner({required this.eval});
  final RuleEvaluation eval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isViolation = eval.isViolation;
    final bg = isViolation
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final fg = isViolation
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isViolation ? Icons.info_outline : Icons.lightbulb_outline,
              color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(eval.message ?? '', style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }
}
