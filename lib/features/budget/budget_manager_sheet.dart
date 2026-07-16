import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';

Future<void> showBudgetManagerSheet(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BudgetManagerSheet(initialDate: initialDate),
  );
}

class BudgetManagerSheet extends StatefulWidget {
  const BudgetManagerSheet({
    super.key,
    this.initialDate,
  });

  final DateTime? initialDate;

  @override
  State<BudgetManagerSheet> createState() => _BudgetManagerSheetState();
}

class _BudgetManagerSheetState extends State<BudgetManagerSheet> {
  late DateTime _editingDate;

  @override
  void initState() {
    super.initState();
    _editingDate = widget.initialDate ?? DateTime.now();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _editingDate = DateTime(
        _editingDate.year,
        _editingDate.month + delta,
        _editingDate.day,
      );
    });
  }

  String _formatRange(DateTimeRange range) {
    final end = range.end.subtract(const Duration(days: 1));
    return '${range.start.year}/${range.start.month}/${range.start.day} - ${end.month}/${end.day}';
  }

  @override
  Widget build(BuildContext context) {
    final store = PocketMeowScope.watch(context);
    final theme = Theme.of(context);
    final range = store.monthlyBudgetRangeFor(_editingDate);
    final buckets = store.budgetBucketsFor(_editingDate);
    final totalBudget = store.totalBudgetFor(_editingDate);

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6EBEE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('预算管理', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          _formatRange(range),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              formatMonthLabel(_editingDate),
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '未主动修改时，默认沿用上一期预算',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text('预算分类', style: theme.textTheme.titleLarge),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _showBucketEditor(
                      context,
                      targetDate: _editingDate,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新增'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...buckets.map(
                (bucket) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => _showBucketEditor(
                        context,
                        targetDate: _editingDate,
                        bucket: bucket,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(bucket.colorValue),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bucket.name,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '预算 ${formatShortCurrency(bucket.limitValue)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '总预算 ${formatShortCurrency(totalBudget)}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${buckets.length} 个预算分类',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _budgetColorOptions = <int>[
  0xFF4DB6AC,
  0xFFE57373,
  0xFF81C784,
  0xFF64B5F6,
  0xFF9575CD,
  0xFFFFB74D,
  0xFF4DD0E1,
  0xFFFF8A5B,
  0xFF8FA8FF,
  0xFFB0BEC5,
];

Future<void> _showBucketEditor(
  BuildContext context, {
  required DateTime targetDate,
  BudgetBucket? bucket,
}) async {
  final store = PocketMeowScope.read(context);
  final theme = Theme.of(context);

  final nameController = TextEditingController(text: bucket?.name ?? '');
  final limitController = TextEditingController(
      text: bucket == null ? '' : bucket.limitValue.toStringAsFixed(0));
  var colorValue = bucket?.colorValue ?? _budgetColorOptions.first;

  final selectedCategoryIds = <String>{
    for (final link in store.budgetBucketCategoriesFor(targetDate))
      if (link.bucketId == bucket?.id) link.categoryId,
  };

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final expenseCategories = store.expenseCategories;
          return AlertDialog(
            title: Text(bucket == null ? '新增预算分类' : '编辑预算分类'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: '预算名称（如 房租）'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '预算额度（元）'),
                  ),
                  const SizedBox(height: 14),
                  Text('颜色', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _budgetColorOptions
                        .map(
                          (value) => InkWell(
                            onTap: () => setState(() => colorValue = value),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Color(value),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: value == colorValue
                                      ? AppTheme.ink
                                      : const Color(0xFFE6EBEE),
                                  width: value == colorValue ? 2 : 1,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('覆盖分类', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: expenseCategories
                        .map(
                          (c) => FilterChip(
                            selected: selectedCategoryIds.contains(c.id),
                            label: Text(c.name),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  selectedCategoryIds.add(c.id);
                                } else {
                                  selectedCategoryIds.remove(c.id);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            actions: [
              if (bucket != null && !bucket.isSystem)
                TextButton(
                  onPressed: () {
                    store.deleteBudgetBucket(bucket.id, targetDate: targetDate);
                    Navigator.of(context).pop();
                  },
                  child: const Text('删除'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final limit =
                      double.tryParse(limitController.text.trim()) ?? 0;

                  if (bucket == null) {
                    store.addBudgetBucket(
                      name: name,
                      limitValue: limit,
                      colorValue: colorValue,
                      targetDate: targetDate,
                    );
                    final created = store.budgetBucketsFor(targetDate)
                        .where((b) => !b.isSystem)
                        .toList()
                      ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
                    if (created.isNotEmpty) {
                      store.setBudgetBucketCategoriesForBucket(
                        created.first.id,
                        selectedCategoryIds,
                        targetDate: targetDate,
                      );
                    }
                  } else {
                    store.updateBudgetBucket(
                      bucket.copyWith(
                        name: name,
                        limitValue: limit,
                        colorValue: colorValue,
                      ),
                      targetDate: targetDate,
                    );
                    store.setBudgetBucketCategoriesForBucket(
                      bucket.id,
                      selectedCategoryIds,
                      targetDate: targetDate,
                    );
                  }

                  Navigator.of(context).pop();
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
}
