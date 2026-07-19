import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _excludeFromBudget = false;
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
      _excludeFromBudget = initialExpense?.excludeFromBudget ?? false;
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? '编辑这笔账' : '快速记一笔',
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (isEditing)
                          IconButton(
                            onPressed: () => _confirmDelete(context, store),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            tooltip: '删除此账单',
                          ),
                      ],
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
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/xX×÷()., ]'),
                        ),
                      ],
                      style: theme.textTheme.headlineMedium,
                      validator: (value) {
                        final amount = _tryParseAmountExpression(value ?? '');
                        if (amount == null || amount <= 0) {
                          return '请输入正确金额';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _applyAmountExpression(),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('选择分类', style: theme.textTheme.titleMedium),
                        if (_recordType == RecordType.expense)
                          Row(
                            children: [
                              Text(
                                '不计入预算',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.muted,
                                ),
                              ),
                              Switch(
                                value: _excludeFromBudget,
                                onChanged: (val) =>
                                    setState(() => _excludeFromBudget = val),
                                activeThumbColor: AppTheme.mintDeep,
                                activeTrackColor:
                                    AppTheme.mint.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                      ],
                    ),
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
                                    onPressed: _pickDateTime,
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
                                final resolvedAmount =
                                    _applyAmountExpression(silent: true);
                                if (!_formKey.currentState!.validate() ||
                                    _selectedCategory == null ||
                                    resolvedAmount == null) {
                                  return;
                                }

                                final amount = resolvedAmount;
                                if (isEditing) {
                                  store.updateRecord(
                                    recordId: widget.expense!.id,
                                    amount: amount,
                                    categoryId: _selectedCategory!,
                                    note: _noteController.text,
                                    type: _recordType,
                                    createdAt: _selectedDateTime,
                                    excludeFromBudget: _excludeFromBudget,
                                  );
                                } else if (_recordType == RecordType.expense) {
                                  store.addExpense(
                                    amount: amount,
                                    categoryId: _selectedCategory!,
                                    note: _noteController.text,
                                    createdAt: _selectedDateTime,
                                    excludeFromBudget: _excludeFromBudget,
                                  );
                                } else {
                                  store.addIncome(
                                    amount: amount,
                                    categoryId: _selectedCategory!,
                                    note: _noteController.text,
                                    createdAt: _selectedDateTime,
                                  );
                                }
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
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
    final picked = await _showDateTimePickerSheet(
      context,
      initialDateTime: _selectedDateTime,
      minDate: DateTime(2020),
      maxDate: DateTime.now(),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDateTime = picked;
    });
  }

  String _formatTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  double? _applyAmountExpression({bool silent = false}) {
    final amount = _tryParseAmountExpression(_amountController.text);
    if (amount == null || amount <= 0) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('金额算式无效')),
        );
      }
      return null;
    }

    final formatted = _formatAmountInput(amount);
    _amountController.value = _amountController.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
    return amount;
  }

  double? _tryParseAmountExpression(String raw) {
    final normalized = raw
        .trim()
        .replaceAll(' ', '')
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll('X', '*')
        .replaceAll('÷', '/')
        .replaceAll('，', ',');
    if (normalized.isEmpty) {
      return null;
    }

    final parser = _AmountExpressionParser(normalized);
    final value = parser.parse();
    if (value == null || value.isNaN || value.isInfinite) {
      return null;
    }
    return value;
  }

  String _formatAmountInput(double value) {
    return value
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  Future<DateTime?> _showDateTimePickerSheet(
    BuildContext context, {
    required DateTime initialDateTime,
    required DateTime minDate,
    required DateTime maxDate,
  }) async {
    DateTime normalize(DateTime value) {
      if (value.isBefore(minDate)) {
        return minDate;
      }
      if (value.isAfter(maxDate)) {
        return maxDate;
      }
      return value;
    }

    final initialValue = normalize(initialDateTime);
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var tempSelected = initialValue;
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final selectedLabel =
                '${formatMonthLabel(tempSelected)} · ${formatDayLabelWithWeekday(tempSelected)} · ${_formatTime(tempSelected)}';
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 360,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('取消'),
                            ),
                            Expanded(
                              child: Text(
                                '设置时间',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(tempSelected),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                minimumSize: const Size(0, 40),
                              ),
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Text(
                          selectedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: CupertinoTheme(
                          data: CupertinoThemeData(
                            brightness: Brightness.light,
                            textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle:
                                  theme.textTheme.titleLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.dateAndTime,
                            use24hFormat: true,
                            minimumDate: minDate,
                            maximumDate: maxDate,
                            initialDateTime: initialValue,
                            onDateTimeChanged: (value) {
                              setState(() {
                                tempSelected = normalize(value);
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _confirmDelete(
      BuildContext context, PocketMeowStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账单'),
        content: const Text('确定要删除这笔账单吗？此操作无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      store.deleteRecord(widget.expense!.id);
      Navigator.of(context).pop();
    }
  }
}

class _AmountExpressionParser {
  _AmountExpressionParser(this.input);

  final String input;
  int _index = 0;

  double? parse() {
    final value = _parseExpression();
    if (value == null) {
      return null;
    }
    _skipSeparators();
    if (_index != input.length) {
      return null;
    }
    return value;
  }

  double? _parseExpression() {
    var value = _parseTerm();
    if (value == null) {
      return null;
    }

    while (true) {
      _skipSeparators();
      final operator = _peek();
      if (operator != '+' && operator != '-') {
        return value;
      }
      _index++;
      final rhs = _parseTerm();
      if (rhs == null) {
        return null;
      }
      final current = value;
      if (current == null) {
        return null;
      }
      value = operator == '+' ? current + rhs : current - rhs;
    }
  }

  double? _parseTerm() {
    var value = _parseFactor();
    if (value == null) {
      return null;
    }

    while (true) {
      _skipSeparators();
      final operator = _peek();
      if (operator != '*' && operator != '/') {
        return value;
      }
      _index++;
      final rhs = _parseFactor();
      if (rhs == null) {
        return null;
      }
      final current = value;
      if (current == null) {
        return null;
      }
      if (operator == '*') {
        value = current * rhs;
      } else {
        if (rhs == 0) {
          return null;
        }
        value = current / rhs;
      }
    }
  }

  double? _parseFactor() {
    _skipSeparators();
    final char = _peek();
    if (char == null) {
      return null;
    }

    if (char == '+') {
      _index++;
      return _parseFactor();
    }
    if (char == '-') {
      _index++;
      final value = _parseFactor();
      return value == null ? null : -value;
    }
    if (char == '(') {
      _index++;
      final value = _parseExpression();
      _skipSeparators();
      if (value == null || _peek() != ')') {
        return null;
      }
      _index++;
      return value;
    }
    return _parseNumber();
  }

  double? _parseNumber() {
    _skipSeparators();
    final start = _index;
    var sawDigit = false;
    var sawDot = false;

    while (_index < input.length) {
      final char = input[_index];
      if (_isDigit(char)) {
        sawDigit = true;
        _index++;
        continue;
      }
      if (char == '.' && !sawDot) {
        sawDot = true;
        _index++;
        continue;
      }
      break;
    }

    if (!sawDigit) {
      return null;
    }
    return double.tryParse(input.substring(start, _index));
  }

  void _skipSeparators() {
    while (_index < input.length &&
        (input[_index] == ' ' || input[_index] == ',')) {
      _index++;
    }
  }

  String? _peek() {
    if (_index >= input.length) {
      return null;
    }
    return input[_index];
  }

  bool _isDigit(String value) {
    final unit = value.codeUnitAt(0);
    return unit >= 48 && unit <= 57;
  }
}
