import 'package:flutter/material.dart';

import '../../../core/program/food_catalog.dart';

/// 먹은 메뉴 목록 편집기.
///
/// - 선택한 메뉴를 "라면 ×1.5" 형태의 칩으로 보여줍니다.
/// - "메뉴 추가"로 검색해서 고르고, 먹은 양(인분/개수)을 입력합니다.
/// - 같은 메뉴를 여러 번 담을 수 있습니다(칩을 눌러 양 수정, ✕ 로 삭제).
class FoodPortionEditor extends StatelessWidget {
  const FoodPortionEditor({
    super.key,
    required this.foods,
    required this.onChanged,
  });

  final List<FoodPortion> foods;
  final ValueChanged<List<FoodPortion>> onChanged;

  Future<void> _add(BuildContext context) async {
    final item = await showFoodSearchSheet(context);
    if (item == null || !context.mounted) return;
    final amount = await showAmountDialog(context, item.label);
    if (amount == null) return;
    onChanged([...foods, FoodPortion(item.id, amount)]);
  }

  Future<void> _editAmount(BuildContext context, int index) async {
    final current = foods[index];
    final amount =
        await showAmountDialog(context, current.label, initial: current.amount);
    if (amount == null) return;
    final next = [...foods];
    next[index] = current.copyWith(amount: amount);
    onChanged(next);
  }

  void _remove(int index) {
    final next = [...foods]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < foods.length; i++)
          InputChip(
            label: Text(foods[i].display),
            onPressed: () => _editAmount(context, i),
            onDeleted: () => _remove(i),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('메뉴 추가'),
          onPressed: () => _add(context),
          side: BorderSide(color: theme.colorScheme.primary),
        ),
      ],
    );
  }
}

/// 메뉴 검색 바텀 시트. 고른 [FoodItem] 을 반환(취소 시 null).
Future<FoodItem?> showFoodSearchSheet(BuildContext context) {
  return showModalBottomSheet<FoodItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _FoodSearchSheet(),
  );
}

class _FoodSearchSheet extends StatefulWidget {
  const _FoodSearchSheet();

  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = FoodCatalog.search(_query);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '메뉴 검색 (예: 라면, 닭가슴살, 튀김)',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('검색 결과가 없어요.'))
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final f = results[i];
                        return ListTile(
                          title: Text(f.label),
                          subtitle: Text(f.categoryLabel),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.pop(context, f),
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}

/// 먹은 양(인분/개수) 입력 다이얼로그. 확정한 값을 반환(취소 시 null).
Future<double?> showAmountDialog(
  BuildContext context,
  String label, {
  double initial = 1,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _AmountDialog(label: label, initial: initial),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.label, required this.initial});

  final String label;
  final double initial;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late double _amount = widget.initial;

  static const _presets = [0.5, 1.0, 1.5, 2.0, 3.0];

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _bump(double delta) {
    setState(() {
      _amount = (_amount + delta).clamp(0.5, 20).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('먹은 양 (인분/개수)'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _amount <= 0.5 ? null : () => _bump(-0.5),
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('×${_fmt(_amount)}',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton.filledTonal(
                onPressed: () => _bump(0.5),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  label: Text('×${_fmt(p)}'),
                  selected: _amount == p,
                  onSelected: (_) => setState(() => _amount = p),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _amount),
          child: const Text('담기'),
        ),
      ],
    );
  }
}
