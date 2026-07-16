import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';
import '../add_expense/add_expense_sheet.dart';
import 'records_page.dart';

class SearchRecordsSheet extends StatefulWidget {
  const SearchRecordsSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<SearchRecordsSheet> createState() => _SearchRecordsSheetState();
}

class _SearchRecordsSheetState extends State<SearchRecordsSheet> {
  final TextEditingController _searchController = TextEditingController();
  RecordType? _selectedType;
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);

    // Filter records
    final query = _searchController.text.trim().toLowerCase();
    var filteredRecords = store.records.where((record) {
      if (_selectedType != null && record.type != _selectedType) {
        return false;
      }
      if (_selectedCategoryId != null &&
          record.categoryId != _selectedCategoryId) {
        return false;
      }
      if (query.isNotEmpty) {
        final category = store.categoryById(record.categoryId);
        final categoryName = category?.name.toLowerCase() ?? '';
        final note = record.note.toLowerCase();
        final amountStr = record.amount.toString();

        if (!categoryName.contains(query) &&
            !note.contains(query) &&
            !amountStr.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    final grouped = groupByDay(filteredRecords, store);

    // Get categories based on selected type
    List<ExpenseCategory> availableCategories = [];
    if (_selectedType == null) {
      availableCategories = store.categories;
    } else {
      availableCategories = store.categoriesForType(_selectedType!);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('搜索与筛选', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search Field
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '搜索备注、分类、金额',
                prefixIcon: const Icon(Icons.search, color: AppTheme.muted),
                filled: true,
                fillColor: const Color(0xFFF1F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Type Filter
                  _FilterChip(
                    label: '全部类型',
                    isSelected: _selectedType == null,
                    onTap: () {
                      setState(() {
                        _selectedType = null;
                        _selectedCategoryId = null; // Reset category filter
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '支出',
                    isSelected: _selectedType == RecordType.expense,
                    onTap: () {
                      setState(() {
                        _selectedType = RecordType.expense;
                        if (_selectedCategoryId != null &&
                            store.categoryById(_selectedCategoryId!)?.type !=
                                RecordType.expense) {
                          _selectedCategoryId = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '收入',
                    isSelected: _selectedType == RecordType.income,
                    onTap: () {
                      setState(() {
                        _selectedType = RecordType.income;
                        if (_selectedCategoryId != null &&
                            store.categoryById(_selectedCategoryId!)?.type !=
                                RecordType.income) {
                          _selectedCategoryId = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: 24,
                    color: const Color(0xFFE6EBEE),
                  ),
                  const SizedBox(width: 16),
                  // Category Filter Dropdown/Button
                  PopupMenuButton<String?>(
                    initialValue: _selectedCategoryId,
                    onSelected: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(
                          value: null,
                          child: Text('全部分类'),
                        ),
                        ...availableCategories.map((c) => PopupMenuItem(
                              value: c.id,
                              child: Row(
                                children: [
                                  Icon(iconForCategory(c.iconKey),
                                      size: 18, color: Color(c.colorValue)),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            )),
                      ];
                    },
                    child: _FilterChip(
                      label: _selectedCategoryId == null
                          ? '全部分类'
                          : store.categoryById(_selectedCategoryId!)?.name ??
                              '未知分类',
                      isSelected: _selectedCategoryId != null,
                      onTap: null, // Let PopupMenuButton handle tap
                      icon: Icons.keyboard_arrow_down_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Results
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Text(
                        '没有找到匹配的记录',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.muted),
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final section = grouped[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                formatDayLabelWithWeekday(section.date),
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(color: AppTheme.muted),
                              ),
                            ),
                            ...section.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: RecordRow(
                                    item: item,
                                    onTap: () {
                                      showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => AddExpenseSheet(
                                            expense: item.record),
                                      );
                                    },
                                  ),
                                )),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.ink : const Color(0xFFF1F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected ? Colors.white : AppTheme.ink,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.ink,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}
