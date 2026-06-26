import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/program/branch_engine.dart';
import '../../core/providers.dart';

/// 주차 점검/분기 화면.
/// - 3주차 이상: 근육 회복·목표 도달 질문 → 반복/진행/유지 안내.
/// - 그 외: 한 주 완료 확인.
class BranchCheckScreen extends ConsumerStatefulWidget {
  const BranchCheckScreen({
    super.key,
    required this.week,
    required this.stageId,
  });

  final int week;
  final String stageId;

  @override
  ConsumerState<BranchCheckScreen> createState() => _BranchCheckScreenState();
}

class _BranchCheckScreenState extends ConsumerState<BranchCheckScreen> {
  bool? _muscle;
  bool? _goal;
  BranchRecommendation? _result;
  bool _saving = false;

  bool get _isBranch => BranchEngine.isBranchWeek(widget.week);

  Future<void> _save({String? branchResult}) async {
    setState(() => _saving = true);
    try {
      await ref.read(supabaseServiceProvider).saveWeekCheck(
            weekNo: widget.week,
            stage: widget.stageId,
            branchResult: branchResult,
          );
      ref.invalidate(weeklyCheckDueProvider);
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

  void _evaluate() {
    if (_muscle == null || _goal == null) return;
    setState(() {
      _result = BranchEngine.evaluate(
        BranchAnswers(muscleRecovered: _muscle!, reachedGoal: _goal!),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.week}주차 점검')),
      body: SafeArea(
        child: _result != null
            ? _ResultView(
                rec: _result!,
                saving: _saving,
                onConfirm: () => _save(branchResult: _result!.result.db),
              )
            : _isBranch
                ? _Questions(
                    muscle: _muscle,
                    goal: _goal,
                    saving: _saving,
                    onMuscle: (v) => setState(() => _muscle = v),
                    onGoal: (v) => setState(() => _goal = v),
                    onSubmit: _evaluate,
                  )
                : _SimpleDone(
                    week: widget.week,
                    saving: _saving,
                    onConfirm: () => _save(),
                  ),
      ),
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({
    required this.muscle,
    required this.goal,
    required this.saving,
    required this.onMuscle,
    required this.onGoal,
    required this.onSubmit,
  });

  final bool? muscle;
  final bool? goal;
  final bool saving;
  final ValueChanged<bool> onMuscle;
  final ValueChanged<bool> onGoal;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = muscle != null && goal != null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('이번 주를 돌아볼게요',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '정답은 없어요. 솔직하게 체크하면 다음 단계를 안내해 드려요.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _YesNo(
                question: '근육량이 회복된 느낌인가요?\n(운동 수행력·컨디션이 돌아왔나요)',
                value: muscle,
                onChanged: onMuscle,
              ),
              const SizedBox(height: 20),
              _YesNo(
                question: '목표한 만큼 감량했다고 느끼나요?',
                value: goal,
                onChanged: onGoal,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: (ready && !saving) ? onSubmit : null,
            child: const Text('결과 보기'),
          ),
        ),
      ],
    );
  }
}

class _YesNo extends StatelessWidget {
  const _YesNo({
    required this.question,
    required this.value,
    required this.onChanged,
  });
  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _choice(context, '네', value == true,
                      () => onChanged(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _choice(context, '아직요', value == false,
                      () => onChanged(false)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor:
            selected ? theme.colorScheme.primaryContainer : null,
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Text(label),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.rec,
    required this.saving,
    required this.onConfirm,
  });
  final BranchRecommendation rec;
  final bool saving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(Icons.insights_outlined,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(rec.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(rec.message, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('이렇게 해보세요',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      for (final g in rec.guidance)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(child: Text(g)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '이 안내는 자기 점검을 돕기 위한 것으로 의학적 진단이 아닙니다. '
                '몸 상태가 걱정되면 전문가와 상담하세요.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: saving ? null : onConfirm,
            child: saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('확인했어요'),
          ),
        ),
      ],
    );
  }
}

class _SimpleDone extends StatelessWidget {
  const _SimpleDone({
    required this.week,
    required this.saving,
    required this.onConfirm,
  });
  final int week;
  final bool saving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('$week주차 완료! 🎉',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '한 주를 잘 지나왔어요. 다음 주도 같은 리듬으로 이어가요.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: saving ? null : onConfirm,
            child: const Text('확인'),
          ),
        ),
      ],
    );
  }
}
