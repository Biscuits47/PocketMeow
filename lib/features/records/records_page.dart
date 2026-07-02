import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';
import '../add_expense/add_expense_sheet.dart';
import '../settings/settings_page.dart';
import 'search_records_sheet.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);
    final grouped = groupByDay(store.records, store);

    final now = DateTime.now();
    final todayExpense = store.records
        .where((r) =>
            r.type == RecordType.expense &&
            r.createdAt.year == now.year &&
            r.createdAt.month == now.month &&
            r.createdAt.day == now.day)
        .fold(0.0, (sum, r) => sum + r.amount);

    final todayIncome = store.records
        .where((r) =>
            r.type == RecordType.income &&
            r.createdAt.year == now.year &&
            r.createdAt.month == now.month &&
            r.createdAt.day == now.day)
        .fold(0.0, (sum, r) => sum + r.amount);

    final actualMonthSpentForBudget = store.records
        .where((r) =>
            r.type == RecordType.expense &&
            r.createdAt.year == now.year &&
            r.createdAt.month == now.month &&
            !r.excludeFromBudget)
        .fold(0.0, (sum, r) => sum + r.amount);

    final actualMonthSpentTotal = store.records
        .where((r) =>
            r.type == RecordType.expense &&
            r.createdAt.year == now.year &&
            r.createdAt.month == now.month)
        .fold(0.0, (sum, r) => sum + r.amount);

    final actualMonthIncome = store.records
        .where((r) =>
            r.type == RecordType.income &&
            r.createdAt.year == now.year &&
            r.createdAt.month == now.month)
        .fold(0.0, (sum, r) => sum + r.amount);

    final actualBudgetUsage = store.totalBudget <= 0
        ? 0.0
        : (actualMonthSpentForBudget / store.totalBudget).clamp(0.0, 1.0);

    final actualBalance = store.totalBudget - actualMonthSpentTotal;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('账单', style: theme.textTheme.headlineMedium),
                _SearchShortcut(onTap: () => _showSearchSheet(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              children: [
                InkWell(
                  onTap: () => showBudgetDialog(context, store),
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF162127), Color(0xFF21493F)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 28,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '今日支出',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      formatCurrency(todayExpense),
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '今日收入',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      formatCurrency(todayIncome),
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: actualBudgetUsage,
                              minHeight: 10,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.10),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                actualBudgetUsage >= 1.0
                                    ? Colors.red
                                    : Color.lerp(AppTheme.mint, Colors.red,
                                            actualBudgetUsage) ??
                                        AppTheme.mint,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '本月支出',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.58),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatShortCurrency(
                                          actualMonthSpentTotal),
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '本月收入',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.58),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatShortCurrency(actualMonthIncome),
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '预算结余',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.58),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatShortCurrency(actualBalance),
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (grouped.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        '没有账单记录。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ),
                ...grouped.map(
                  (section) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DaySection(section: section),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.section});

  final GroupedRecords section;

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
                Text(formatDayLabel(section.date),
                    style: theme.textTheme.titleLarge),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (section.expense > 0)
                      Text(
                        '- ${formatShortCurrency(section.expense)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    if (section.expense > 0 && section.income > 0)
                      const SizedBox(width: 8),
                    if (section.income > 0)
                      Text(
                        '+ ${formatShortCurrency(section.income)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
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
                    child:
                        const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: RecordRow(
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

class RecordItem {
  const RecordItem({
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

class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  final RecordItem item;
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.record.excludeFromBudget &&
                        item.type == RecordType.expense) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '不计入预算',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.record.note.isNotEmpty
                      ? '${item.time} · ${item.record.note}'
                      : item.time,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class GroupedRecords {
  const GroupedRecords({
    required this.date,
    required this.items,
    required this.expense,
    required this.income,
  });

  final DateTime date;
  final List<RecordItem> items;
  final double expense;
  final double income;
}

List<GroupedRecords> groupByDay(
  List<ExpenseRecord> records,
  PocketMeowStore store,
) {
  final map = <String, List<ExpenseRecord>>{};
  for (final item in records) {
    final key =
        '${item.createdAt.year}-${item.createdAt.month}-${item.createdAt.day}';
    map.putIfAbsent(key, () => []).add(item);
  }

  final result = map.entries.map((entry) {
    // 降序排序：晚的在上面（b.createdAt.compareTo(a.createdAt)），早的在下面
    final items = [...entry.value]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final date = items.first.createdAt;
    final mapped = items.map((record) {
      final category = store.categoryById(record.categoryId);
      return RecordItem(
        id: record.id,
        title: category?.name ?? '未分类',
        category: category?.name ?? '未分类',
        amount: record.amount,
        time:
            '${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}',
        iconKey: category?.iconKey ?? 'wallet',
        record: record,
        type: record.type,
      );
    }).toList();
    final income = mapped
        .where((item) => item.type == RecordType.income)
        .fold(0.0, (sum, item) => sum + item.amount);
    final expense = mapped
        .where((item) => item.type == RecordType.expense)
        .fold(0.0, (sum, item) => sum + item.amount);
    return GroupedRecords(
      date: date,
      items: mapped,
      expense: expense,
      income: income,
    );
  }).toList();

  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
}

class _SearchShortcut extends StatelessWidget {
  const _SearchShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EBEE)),
        ),
        child: const Icon(Icons.search_rounded),
      ),
    );
  }
}

void _showSearchSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return SearchRecordsSheet(scrollController: scrollController);
      },
    ),
  );
}
