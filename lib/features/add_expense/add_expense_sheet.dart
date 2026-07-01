import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';
import '../settings/settings_page.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({
    super.key,
    this.expense,
  });

  final ExpenseRecord? expense;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  RecordType _recordType = RecordType.expense;
  DateTime _selectedDateTime = DateTime.now();
  bool _initialized = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final store = PocketMeowScope.read(context);
    if (!_initialized) {
      final initialExpense = widget.expense;
      _recordType = initialExpense?.type ?? RecordType.expense;
      final initialCategories = store.categoriesForType(_recordType);
      _selectedCategory = initialExpense?.categoryId ??
          (initialCategories.isNotEmpty ? initialCategories.first.id : null);
      _amountController.text = initialExpense?.amount.toStringAsFixed(2) ?? '';
      _noteController.text = initialExpense?.note ?? '';
      _selectedDateTime = initialExpense?.createdAt ?? DateTime.now();
      _initialized = true;
    }
    final isEditing = widget.expense != null;
    final categories = store.categoriesForType(_recordType);
    if (_selectedCategory != null &&
        categories.every((item) => item.id != _selectedCategory)) {
      _selectedCategory = categories.isNotEmpty ? categories.first.id : null;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE4E8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isEditing ? '编辑这笔账' : '快速记一笔',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<RecordType>(
                      segments: const [
                        ButtonSegment<RecordType>(
                          value: RecordType.expense,
                          label: Text('支出'),
                          icon: Icon(Icons.arrow_upward_rounded),
                        ),
                        ButtonSegment<RecordType>(
                          value: RecordType.income,
                          label: Text('收入'),
                          icon: Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                      selected: {_recordType},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _recordType = selection.first;
                          final next = store.categoriesForType(_recordType);
                          _selectedCategory =
                              next.isNotEmpty ? next.first.id : null;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: theme.textTheme.headlineMedium,
                      validator: (value) {
                        final amount = double.tryParse((value ?? '').trim());
                        if (amount == null || amount <= 0) {
                          return '请输入正确金额';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText: '输入金额',
                        prefixText: '¥ ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        hintText: '备注',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('选择分类', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ...categories.map((category) {
                          final selected = category.id == _selectedCategory;
                          return ChoiceChip(
                            avatar: Icon(
                              iconForCategory(category.iconKey),
                              size: 18,
                              color:
                                  selected ? AppTheme.mintDeep : AppTheme.muted,
                            ),
                            label: Text(category.name),
                            selected: selected,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = category.id;
                              });
                            },
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded,
                              size: 18, color: AppTheme.mintDeep),
                          label: const Text('新分类'),
                          onPressed: () {
                            showAddCategoryDialog(context, store);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _pickDateTime,
                            child: Ink(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 20,
                                    color: AppTheme.muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${formatMonthLabel(_selectedDateTime)} · ${formatDayLabel(_selectedDateTime)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '时间 ${_formatTime(_selectedDateTime)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: AppTheme.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _pickDate,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.event_outlined,
                                        size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: () {
                                if (!_formKey.currentState!.validate() ||
                                    _selectedCategory == null) {
                                  return;
                                }

                                final amount =
                                    double.parse(_amountController.text.trim());
                                if (isEditing) {
                                  store.updateRecord(
                                    recordId: widget.expense!.id,
                                    amount: amount,
                                    categoryId: _selectedCategory!,
                                    note: _noteController.text,
                                    type: _recordType,
                                    createdAt: _selectedDateTime,
                                  );
                                } else if (_recordType == RecordType.expense) {
                                  store.addExpense(
                                    amount: amount,
                                    categoryId: _selectedCategory!,
                                    note: _noteController.text,
                                    createdAt: _selectedDateTime,
                                  );
                                } else {
                                  store.addIncome(
                                    amount: amount,
                                    categoryId: _selectedCategory!,
                                    note: _noteController.text,
                                    createdAt: _selectedDateTime,
                                  );
                                }
                                Navigator.of(context).pop();
                              },
                              child: Text(isEditing ? '更新' : '保存'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    await _pickDate();
    if (!mounted) {
      return;
    }
    await _pickTime();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String _formatTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
