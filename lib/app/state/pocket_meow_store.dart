import 'package:flutter/material.dart';

import '../../data/local/app_storage.dart';
import '../../data/models/app_models.dart';

enum ReportType { weekly, monthly, yearly }

class PocketMeowStore extends ChangeNotifier {
  PocketMeowStore({AppStorage? storage}) : _storage = storage ?? AppStorage();

  final AppStorage _storage;

  bool _isReady = false;
  double _totalBudget = 6000;
  DateTime _selectedDate = DateTime.now();
  ReportType _reportType = ReportType.monthly;
  List<ExpenseCategory> _categories = const [];
  List<ExpenseRecord> _records = const [];

  bool get isReady => _isReady;
  double get totalBudget => _totalBudget;
  DateTime get selectedMonth => _selectedDate; // kept for compatibility
  DateTime get selectedDate => _selectedDate;
  ReportType get reportType => _reportType;
  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  List<ExpenseRecord> get records => List.unmodifiable(_sortedRecords);
  List<ExpenseRecord> get expenses => List.unmodifiable(_sortedRecords);

  List<ExpenseCategory> get expenseCategories =>
      categoriesForType(RecordType.expense);
  List<ExpenseCategory> get incomeCategories =>
      categoriesForType(RecordType.income);
  List<ExpenseCategory> get customCategories =>
      _categories.where((item) => !item.isSystem).toList();

  List<ExpenseRecord> get _sortedRecords {
    final list = [..._records];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  bool get canGoToNextMonth {
    final now = DateTime.now();
    if (_reportType == ReportType.yearly) {
      return _selectedDate.year < now.year;
    } else if (_reportType == ReportType.monthly) {
      return _selectedDate.year < now.year ||
          (_selectedDate.year == now.year && _selectedDate.month < now.month);
    } else {
      final startOfCurrentWeek =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final startOfNowWeek = now.subtract(Duration(days: now.weekday - 1));
      return startOfCurrentWeek.isBefore(startOfNowWeek);
    }
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

  List<ExpenseRecord> recordsForPeriod(DateTime date, ReportType type) {
    return _sortedRecords.where((item) {
      if (type == ReportType.yearly) {
        return item.createdAt.year == date.year;
      } else if (type == ReportType.monthly) {
        return item.createdAt.year == date.year &&
            item.createdAt.month == date.month;
      } else {
        // weekly
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final itemDate = DateTime(
            item.createdAt.year, item.createdAt.month, item.createdAt.day);
        final start =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        return itemDate.isAfter(start.subtract(const Duration(days: 1))) &&
            itemDate.isBefore(end.add(const Duration(days: 1)));
      }
    }).toList();
  }

  List<ExpenseRecord> get currentMonthRecords {
    return recordsForPeriod(_selectedDate, _reportType);
  }

  void setReportType(ReportType type) {
    _reportType = type;
    notifyListeners();
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

  double get monthSpent =>
      currentMonthExpenses.fold(0.0, (sum, item) => sum + item.amount);
  double get monthIncome =>
      currentMonthIncomes.fold(0.0, (sum, item) => sum + item.amount);
  double get monthNet => monthIncome - monthSpent;

  double monthSpentFor(DateTime month) =>
      monthAmountOf(RecordType.expense, month: month);
  double monthIncomeFor(DateTime month) =>
      monthAmountOf(RecordType.income, month: month);

  double get remainingBudget => _totalBudget - monthSpent;

  double get forecastEndOfMonth {
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
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

  int _uuidCounter = 0;

  void addRecord({
    required double amount,
    required String categoryId,
    required String note,
    required RecordType type,
    DateTime? createdAt,
  }) {
    _uuidCounter++;
    final record = ExpenseRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}_$_uuidCounter',
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
    DateTime? createdAt,
  }) {
    _records = _records
        .map(
          (item) => item.id == recordId
              ? item.copyWith(
                  amount: amount,
                  categoryId: categoryId,
                  note: note.trim(),
                  type: type,
                  createdAt: createdAt ?? item.createdAt,
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
    _selectedDate = DateTime(month.year, month.month, month.day);
    notifyListeners();
  }

  void goToPreviousMonth() {
    if (_reportType == ReportType.yearly) {
      _selectedDate = DateTime(
          _selectedDate.year - 1, _selectedDate.month, _selectedDate.day);
    } else if (_reportType == ReportType.monthly) {
      _selectedDate = DateTime(
          _selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
    } else {
      _selectedDate = _selectedDate.subtract(const Duration(days: 7));
    }
    notifyListeners();
  }

  void goToNextMonth() {
    if (!canGoToNextMonth) {
      return;
    }
    if (_reportType == ReportType.yearly) {
      _selectedDate = DateTime(
          _selectedDate.year + 1, _selectedDate.month, _selectedDate.day);
    } else if (_reportType == ReportType.monthly) {
      _selectedDate = DateTime(
          _selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
    } else {
      _selectedDate = _selectedDate.add(const Duration(days: 7));
    }
    notifyListeners();
  }

  void resetDemoData() {
    _seedInitialData();
    notifyListeners();
    _persist();
  }

  Future<String> dataSafetySummary() {
    return _storage.dataSafetySummary();
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
              item.categoryId == categoryId &&
              (type == null || item.type == type),
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double spentForCategory(String categoryId) {
    return amountForCategory(
      categoryId,
      month: null, // use currentMonthRecords
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
              month: null, // use currentMonthRecords
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
      final month = DateTime(_selectedDate.year, _selectedDate.month - i);
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

    if (_totalBudget > 0 && monthSpent > _totalBudget) {
      final overBy = monthSpent - _totalBudget;
      return '本月总支出已超出预算 ${overBy.toStringAsFixed(0)} 元，建议先控制大额消费。';
    }

    if (_totalBudget > 0 && budgetUsage >= 0.85) {
      final remaining = remainingBudget > 0 ? remainingBudget : 0;
      return '本月预算已使用 ${(budgetUsage * 100).round()}%，当前剩余 ${remaining.toStringAsFixed(0)} 元。';
    }

    if (monthNet < 0) {
      return '这个月支出高于收入 ${monthNet.abs().toStringAsFixed(0)} 元，建议关注大额支出分类。';
    }

    final topExpense =
        categorySpendData.isEmpty ? null : categorySpendData.first;
    if (topExpense != null) {
      final ratio =
          monthSpent == 0 ? 0 : (topExpense.amount / monthSpent * 100).round();
      return '${topExpense.category.name} 是本月最大支出，占总支出的 $ratio%，是最值得关注的消费方向。';
    }

    return '本月现金流结构比较平衡，继续保持。';
  }

  double get previousMonthSpent {
    final previous = DateTime(_selectedDate.year, _selectedDate.month - 1);
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
        _selectedDate.year == now.year && _selectedDate.month == now.month;
    if (isCurrentMonth) {
      return DateTime(now.year, now.month, now.day);
    }
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    return DateTime(lastDay.year, lastDay.month, lastDay.day);
  }

  int get _forecastReferenceDay {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedDate.year == now.year && _selectedDate.month == now.month;
    if (isCurrentMonth) {
      return now.day;
    }
    return DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
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
        limit: 0,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'transport',
        name: '交通',
        colorValue: 0xFF8FA8FF,
        iconKey: 'train',
        limit: 0,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'shopping',
        name: '购物',
        colorValue: 0xFFFF8A5B,
        iconKey: 'shopping',
        limit: 0,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'entertainment',
        name: '娱乐',
        colorValue: 0xFFB39DDB,
        iconKey: 'movie',
        limit: 0,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'daily',
        name: '日用',
        colorValue: 0xFF6FC3D6,
        iconKey: 'home',
        limit: 0,
        type: RecordType.expense,
        isSystem: true,
      ),
      ExpenseCategory(
        id: 'medical',
        name: '医疗',
        colorValue: 0xFFE57373,
        iconKey: 'medical',
        limit: 0,
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
    final element =
        context.getElementForInheritedWidgetOfExactType<PocketMeowScope>();
    final scope = element?.widget as PocketMeowScope?;
    assert(scope != null, 'PocketMeowScope not found in widget tree.');
    return scope!.notifier!;
  }
}
