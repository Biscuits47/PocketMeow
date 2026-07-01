import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';
import '../add_expense/add_expense_sheet.dart';
import '../settings/settings_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final TextEditingController _searchController = TextEditingController();
  RecordType? _typeFilter;
  String? _categoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);
    final filtered = _applyFilters(store);
    final grouped = _groupByDay(filtered, store);
    final selectedCategory = _categoryFilter == null
        ? null
        : store.categoryById(_categoryFilter!);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('全部账单', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      '按天查看 ${formatMonthLabel(store.selectedMonth)} 的每一笔收支。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _MonthSwitchCompact(store: store),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => openSettingsPage(context),
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6EBEE)),
                  ),
                  child: const Icon(Icons.settings_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索备注或分类',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FilterChipButton(
                label: '全部',
                selected: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
              ),
              _FilterChipButton(
                label: '支出',
                selected: _typeFilter == RecordType.expense,
                onTap: () => setState(() => _typeFilter = RecordType.expense),
              ),
              _FilterChipButton(
                label: '收入',
                selected: _typeFilter == RecordType.income,
                onTap: () => setState(() => _typeFilter = RecordType.income),
              ),
              _FilterChipButton(
                label: selectedCategory?.name ?? '分类筛选',
                selected: _categoryFilter != null,
                onTap: () => _showCategoryFilter(context, store),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryStrip(
            count: filtered.length,
            income: filtered
                .where((item) => item.type == RecordType.income)
                .fold(0.0, (sum, item) => sum + item.amount),
            expense: filtered
                .where((item) => item.type == RecordType.expense)
                .fold(0.0, (sum, item) => sum + item.amount),
          ),
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '当前筛选条件下没有账单记录。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ),
          ...grouped.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _DaySection(section: section),
            ),
          ),
        ],
      ),
    );
  }

  List<ExpenseRecord> _applyFilters(PocketMeowStore store) {
    final query = _searchController.text.trim().toLowerCase();
    return store.currentMonthRecords.where((item) {
      final category = store.categoryById(item.categoryId);
      final categoryName = category?.name.toLowerCase() ?? '';
      final note = item.note.toLowerCase();
      final typePass = _typeFilter == null || item.type == _typeFilter;
      final categoryPass =
          _categoryFilter == null || item.categoryId == _categoryFilter;
      final queryPass = query.isEmpty ||
          note.contains(query) ||
          categoryName.contains(query);
      return typePass && categoryPass && queryPass;
    }).toList();
  }

  Future<void> _showCategoryFilter(
    BuildContext context,
    PocketMeowStore store,
  ) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                ListTile(
                  title: const Text('全部分类'),
                  onTap: () => Navigator.of(context).pop(''),
                ),
                ...store.categories.map(
                  (category) => ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(category.colorValue).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        iconForCategory(category.iconKey),
                        size: 18,
                        color: Color(category.colorValue),
                      ),
                    ),
                    title: Text(category.name),
                    subtitle: Text(category.type.label),
                    onTap: () => Navigator.of(context).pop(category.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _categoryFilter = (result == null || result.isEmpty) ? null : result;
    });
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.count,
    required this.income,
    required this.expense,
  });

  final int count;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryChip(label: '$count 笔')),
        const SizedBox(width: 10),
        Expanded(child: _SummaryChip(label: '+${formatShortCurrency(income)}')),
        const SizedBox(width: 10),
        Expanded(child: _SummaryChip(label: '-${formatShortCurrency(expense)}')),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBEE)),
      ),
      alignment: Alignment.center,
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.section});

  final _GroupedRecords section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.read(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Text(formatDayLabel(section.date), style: theme.textTheme.titleLarge),
                const Spacer(),
                Text(
                  section.net >= 0
                      ? '+${formatShortCurrency(section.net)}'
                      : '-${formatShortCurrency(section.net.abs())}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: section.net >= 0 ? AppTheme.mintDeep : AppTheme.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...section.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => store.deleteRecord(item.id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: _RecordRow(
                    item: item,
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => AddExpenseSheet(expense: item.record),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordItem {
  const _RecordItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.time,
    required this.iconKey,
    required this.record,
    required this.type,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final String time;
  final String iconKey;
  final ExpenseRecord record;
  final RecordType type;
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.item,
    required this.onTap,
  });

  final _RecordItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(iconForCategory(item.iconKey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${item.category} · ${item.time}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatSignedAmount(item.amount, item.type),
            style: theme.textTheme.titleMedium?.copyWith(
              color: item.type == RecordType.income
                  ? AppTheme.mintDeep
                  : AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedRecords {
  const _GroupedRecords({
    required this.date,
    required this.items,
    required this.net,
  });

  final DateTime date;
  final List<_RecordItem> items;
  final double net;
}

List<_GroupedRecords> _groupByDay(
  List<ExpenseRecord> records,
  PocketMeowStore store,
) {
  final map = <String, List<ExpenseRecord>>{};
  for (final item in records) {
    final key = '${item.createdAt.year}-${item.createdAt.month}-${item.createdAt.day}';
    map.putIfAbsent(key, () => []).add(item);
  }

  final result = map.entries.map((entry) {
    final items = [...entry.value]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final date = items.first.createdAt;
    final mapped = items.map((record) {
      final category = store.categoryById(record.categoryId);
      return _RecordItem(
        id: record.id,
        title: record.note.isEmpty ? (category?.name ?? '未分类') : record.note,
        category: category?.name ?? '未分类',
        amount: record.amount,
        time: '${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}',
        iconKey: category?.iconKey ?? 'wallet',
        record: record,
        type: record.type,
      );
    }).toList();
    final income = items
        .where((item) => item.type == RecordType.income)
        .fold(0.0, (sum, item) => sum + item.amount);
    final expense = items
        .where((item) => item.type == RecordType.expense)
        .fold(0.0, (sum, item) => sum + item.amount);
    return _GroupedRecords(date: date, items: mapped, net: income - expense);
  }).toList();

  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
}

class _MonthSwitchCompact extends StatelessWidget {
  const _MonthSwitchCompact({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBEE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: store.goToPreviousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
            visualDensity: VisualDensity.compact,
          ),
          Text(formatShortMonthLabel(store.selectedMonth)),
          IconButton(
            onPressed: store.canGoToNextMonth ? store.goToNextMonth : null,
            icon: const Icon(Icons.chevron_right_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
