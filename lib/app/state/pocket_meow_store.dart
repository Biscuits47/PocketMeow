import 'package:flutter/material.dart';

import '../../data/local/app_storage.dart';
import '../../data/models/app_models.dart';

class PocketMeowStore extends ChangeNotifier {
  PocketMeowStore({AppStorage? storage}) : _storage = storage ?? AppStorage();

  final AppStorage _storage;

  bool _isReady = false;
  double _totalBudget = 6000;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<ExpenseCategory> _categories = const [];
  List<ExpenseRecord> _records = const [];

  bool get isReady => _isReady;
  double get totalBudget => _totalBudget;
  DateTime get selectedMonth => _selectedMonth;
  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  List<ExpenseRecord> get records => List.unmodifiable(_sortedRecords);
  List<ExpenseRecord> get expenses => List.unmodifiable(_sortedRecords);

  List<ExpenseCategory> get expenseCategories => categoriesForType(RecordType.expense);
  List<ExpenseCategory> get incomeCategories => categoriesForType(RecordType.income);
  List<ExpenseCategory> get customCategories =>
      _categories.where((item) => !item.isSystem).toList();

  List<ExpenseRecord> get _sortedRecords {
    final list = [..._records];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  bool get canGoToNextMonth {
    final now = DateTime.now();
    return _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);
  }

  Future<void> load() async {
    final snapshot = await _storage.loadSnapshot();
    if (snapshot == null) {
      _seedInitialData();
      await _persist();
    } else {
      _totalBudget = snapshot.totalBudget;
      _categories = snapshot.categories;
      _records = snapshot.expenses;
    }

    _isReady = true;
    notifyListeners();
  }

  List<ExpenseCategory> categoriesForType(RecordType type) {
    return _categories.where((item) => item.type == type).toList();
  }

  List<ExpenseRecord> recordsForMonth(DateTime month) {
    return _sortedRecords.where((item) {
      return item.createdAt.year == month.year &&
          item.createdAt.month == month.month;
    }).toList();
  }

  List<ExpenseRecord> currentMonthRecordsOf(RecordType type) {
    return currentMonthRecords.where((item) => item.type == type).toList();
  }

  List<ExpenseRecord> recordsForType(
    RecordType type, {
    DateTime? month,
  }) {
    final source = month == null ? _sortedRecords : recordsForMonth(month);
    return source.where((item) => item.type == type).toList();
  }

  List<ExpenseRecord> get currentMonthRecords {
    return recordsForMonth(_selectedMonth);
  }

  List<ExpenseRecord> get currentMonthExpenses {
    return currentMonthRecordsOf(RecordType.expense);
  }

  List<ExpenseRecord> get currentMonthIncomes {
    return currentMonthRecordsOf(RecordType.income);
  }

  double monthAmountOf(RecordType type, {DateTime? month}) {
    return recordsForType(type, month: month)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get monthSpent => monthAmountOf(RecordType.expense, month: _selectedMonth);
  double get monthIncome => monthAmountOf(RecordType.income, month: _selectedMonth);
  double get monthNet => monthIncome - monthSpent;

  double monthSpentFor(DateTime month) => monthAmountOf(RecordType.expense, month: month);
  double monthIncomeFor(DateTime month) => monthAmountOf(RecordType.income, month: month);

  double get remainingBudget => _totalBudget - monthSpent;

  double get forecastEndOfMonth {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final referenceDay = _forecastReferenceDay;
    final dailyAverage = referenceDay == 0 ? 0.0 : monthSpent / referenceDay;
    return dailyAverage * daysInMonth;
  }

  double get projectedBalance => _totalBudget - forecastEndOfMonth;

  double get budgetUsage {
    if (_totalBudget <= 0) {
      return 0;
    }
    return (monthSpent / _totalBudget).clamp(0.0, 1.0);
  }

  void addRecord({
    required double amount,
    required String categoryId,
    required String note,
    required RecordType type,
    DateTime? createdAt,
  }) {
    final record = ExpenseRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      categoryId: categoryId,
      note: note.trim(),
      createdAt: createdAt ?? DateTime.now(),
      type: type,
    );
    _records = [..._records, record];
    notifyListeners();
    _persist();
  }

  void addExpense({
    required double amount,
    required String categoryId,
    required String note,
    DateTime? createdAt,
  }) {
    addRecord(
      amount: amount,
      categoryId: categoryId,
      note: note,
      type: RecordType.expense,
      createdAt: createdAt,
    );
  }

  void addIncome({
    required double amount,
    required String categoryId,
    required String note,
    DateTime? createdAt,
  }) {
    addRecord(
      amount: amount,
      categoryId: categoryId,
      note: note,
      type: RecordType.income,
      createdAt: createdAt,
    );
  }

  void updateRecord({
    required String recordId,
    required double amount,
    required String categoryId,
    required String note,
    required RecordType type,
  }) {
    _records = _records
        .map(
          (item) => item.id == recordId
              ? item.copyWith(
                  amount: amount,
                  categoryId: categoryId,
                  note: note.trim(),
                  type: type,
                )
              : item,
        )
        .toList();
    notifyListeners();
    _persist();
  }

  void updateExpense({
    required String expenseId,
    required double amount,
    required String categoryId,
    required String note,
  }) {
    final record = recordById(expenseId);
    if (record == null) {
      return;
    }
    updateRecord(
      recordId: expenseId,
      amount: amount,
      categoryId: categoryId,
      note: note,
      type: record.type,
    );
  }

  void deleteRecord(String recordId) {
    _records = _records.where((item) => item.id != recordId).toList();
    notifyListeners();
    _persist();
  }

  void deleteExpense(String expenseId) {
    deleteRecord(expenseId);
  }

  void updateTotalBudget(double value) {
    _totalBudget = value;
    notifyListeners();
    _persist();
  }

  void updateCategoryBudget(String categoryId, double value) {
    _categories = _categories
        .map(
          (item) => item.id == categoryId ? item.copyWith(limit: value) : item,
        )
        .toList();
    notifyListeners();
    _persist();
  }

  void addCategory({
    required String name,
    required RecordType type,
    required String iconKey,
    required int colorValue,
    double? limit,
  }) {
    final category = ExpenseCategory(
      id: '${type.key}_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      colorValue: colorValue,
      iconKey: iconKey,
      limit: limit ?? 0,
      type: type,
      isSystem: false,
    );
    _categories = [..._categories, category];
    notifyListeners();
    _persist();
  }

  void deleteCategory(String categoryId) {
    final category = categoryById(categoryId);
    if (category == null || category.isSystem) {
      return;
    }
    final isUsed = _records.any((item) => item.categoryId == categoryId);
    if (isUsed) {
      return;
    }
    _categories = _categories.where((item) => item.id != categoryId).toList();
    notifyListeners();
    _persist();
  }

  void selectMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void goToPreviousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    notifyListeners();
  }

  void goToNextMonth() {
    if (!canGoToNextMonth) {
      return;
    }
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    notifyListeners();
  }

  void resetDemoData() {
    _seedInitialData();
    notifyListeners();
    _persist();
  }

  ExpenseCategory? categoryById(String id) {
    for (final item in _categories) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  ExpenseRecord? recordById(String id) {
    for (final item in _records) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  double amountForCategory(
    String categoryId, {
    DateTime? month,
    RecordType? type,
  }) {
    final source = month == null ? currentMonthRecords : recordsForMonth(month);
    return source
        .where(
          (item) =>
              item.categoryId == categoryId && (type == null || item.type == type),
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double spentForCategory(String categoryId) {
    return amountForCategory(
      categoryId,
      month: _selectedMonth,
      type: RecordType.expense,
    );
  }

  List<CategorySpendData> categoryDataForType(RecordType type) {
    final list = categoriesForType(type)
        .map(
          (category) => CategorySpendData(
            category: category,
            amount: amountForCategory(
              category.id,
              month: _selectedMonth,
              type: type,
            ),
          ),
        )
        .where((item) => item.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  List<CategorySpendData> get categorySpendData {
    return categoryDataForType(RecordType.expense);
  }

  List<DailySpendData> get recentDailySpend {
    final anchor = _recentTrendAnchor;
    final items = <DailySpendData>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(anchor.year, anchor.month, anchor.day - i);
      final expense = currentMonthExpenses
          .where(
            (item) =>
                item.createdAt.year == day.year &&
                item.createdAt.month == day.month &&
                item.createdAt.day == day.day,
          )
          .fold(0.0, (sum, item) => sum + item.amount);
      final income = currentMonthIncomes
          .where(
            (item) =>
                item.createdAt.year == day.year &&
                item.createdAt.month == day.month &&
                item.createdAt.day == day.day,
          )
          .fold(0.0, (sum, item) => sum + item.amount);
      items.add(
        DailySpendData(
          date: day,
          expense: expense,
          income: income,
        ),
      );
    }
    return items;
  }

  List<MonthSpendData> get recentMonthlySpend {
    final items = <MonthSpendData>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(_selectedMonth.year, _selectedMonth.month - i);
      items.add(
        MonthSpendData(
          month: month,
          expense: monthSpentFor(month),
          income: monthIncomeFor(month),
        ),
      );
    }
    return items;
  }

  String get primaryInsight {
    if (currentMonthRecords.isEmpty) {
      return '还没有账单，先记下第一笔收入或支出，钱喵就能开始分析你的现金流。';
    }

    final overspent = expenseCategories
        .where((item) => item.limit > 0 && spentForCategory(item.id) > item.limit)
        .toList();
    if (overspent.isNotEmpty) {
      final item = overspent.first;
      final overBy = spentForCategory(item.id) - item.limit;
      return '${item.name} 已超出预算 ${overBy.toStringAsFixed(0)} 元，建议优先控制这一类消费。';
    }

    if (monthNet < 0) {
      return '这个月支出高于收入 ${monthNet.abs().toStringAsFixed(0)} 元，建议关注大额支出分类。';
    }

    final topExpense = categorySpendData.isEmpty ? null : categorySpendData.first;
    if (topExpense != null) {
      final ratio = monthSpent == 0 ? 0 : (topExpense.amount / monthSpent * 100).round();
      return '${topExpense.category.name} 是本月最大支出，占总支出的 $ratio%，是最值得关注的消费方向。';
    }

    return '本月现金流结构比较平衡，继续保持。';
  }

  double get previousMonthSpent {
    final previous = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    return monthSpentFor(previous);
  }

  String get monthComparisonText {
    final previous = previousMonthSpent;
    if (previous == 0 && monthSpent == 0) {
      return '当前月份和上个月都还没有支出记录。';
    }
    if (previous == 0) {
      return '这是当前记录周期的第一批支出数据，还没有上个月可供对比。';
    }
    final delta = monthSpent - previous;
    final ratio = (delta.abs() / previous * 100).round();
    final trend = delta >= 0 ? '增加' : '减少';
    return '相比上个月，支出$trend了 ${formatAmount(delta.abs())}，约 $ratio%。';
  }

  AppSnapshot get _snapshot {
    return AppSnapshot(
      totalBudget: _totalBudget,
      categories: _categories,
      expenses: _records,
    );
  }

  Future<void> _persist() async {
    await _storage.saveSnapshot(_snapshot);
  }

  DateTime get _recentTrendAnchor {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    if (isCurrentMonth) {
      return DateTime(now.year, now.month, now.day);
    }
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    return DateTime(lastDay.year, lastDay.month, lastDay.day);
  }

  int get _forecastReferenceDay {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    if (isCurrentMonth) {
      return now.day;
    }
    return DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
  }

  void _seedInitialData() {
    _totalBudget = 6000;
    _categories = const [
      ExpenseCategory(
        id: 'salary',
        name: '工资',
        colorValue: 0xFF143D35,
        iconKey: 'salary',
        limit: 0,
        type: RecordType.income,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'bonus',
        name: '奖金',
        colorValue: 0xFF6FC3D6,
        iconKey: 'gift',
        limit: 0,
        type: RecordType.income,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'food',
        name: '餐饮',
        colorValue: 0xFF63D3B1,
        iconKey: 'restaurant',
        limit: 2200,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'transport',
        name: '交通',
        colorValue: 0xFF8FA8FF,
        iconKey: 'train',
        limit: 600,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'shopping',
        name: '购物',
        colorValue: 0xFFFF8A5B,
        iconKey: 'shopping',
        limit: 1200,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'entertainment',
        name: '娱乐',
        colorValue: 0xFFB39DDB,
        iconKey: 'movie',
        limit: 800,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'daily',
        name: '日用',
        colorValue: 0xFF6FC3D6,
        iconKey: 'home',
        limit: 700,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'medical',
        name: '医疗',
        colorValue: 0xFFE57373,
        iconKey: 'medical',
        limit: 500,
        type: RecordType.expense,
        isSystem: true,
      ),
    ];
    _records = const [];
  }
}

class CategorySpendData {
  CategorySpendData({
    required this.category,
    required this.amount,
  });

  final ExpenseCategory category;
  final double amount;

  double shareOf(double total) {
    if (total <= 0) {
      return 0;
    }
    return amount / total;
  }
}

class DailySpendData {
  DailySpendData({
    required this.date,
    required this.expense,
    required this.income,
  });

  final DateTime date;
  final double expense;
  final double income;

  double get net => income - expense;
}

class MonthSpendData {
  MonthSpendData({
    required this.month,
    required this.expense,
    required this.income,
  });

  final DateTime month;
  final double expense;
  final double income;

  double get net => income - expense;
}

String formatAmount(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()} 元';
  }
  return '${value.toStringAsFixed(2)} 元';
}

class PocketMeowScope extends InheritedNotifier<PocketMeowStore> {
  const PocketMeowScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  static PocketMeowStore watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PocketMeowScope>();
    assert(scope != null, 'PocketMeowScope not found in widget tree.');
    return scope!.notifier!;
  }

  static PocketMeowStore read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<PocketMeowScope>();
    final scope = element?.widget as PocketMeowScope?;
    assert(scope != null, 'PocketMeowScope not found in widget tree.');
    return scope!.notifier!;
  }
}
