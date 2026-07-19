import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import '../../core/services/auto_bookkeeping_service.dart';
import '../../data/local/app_storage.dart';
import '../../data/models/app_models.dart';

enum ReportType { weekly, monthly, yearly }

void _reportStoreDebugEvent({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
}) {
  (() async {
    var serverUrl = 'http://192.168.31.33:7777/event';
    const sessionId = 'auto-bookkeeping-crash';
    try {
      final env = await File('.dbg/auto-bookkeeping-crash.env').readAsString();
      for (final line in env.split('\n')) {
        if (line.startsWith('DEBUG_SERVER_URL=')) {
          serverUrl = line.substring('DEBUG_SERVER_URL='.length).trim();
        }
      }
    } catch (_) {}
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(serverUrl));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'sessionId': sessionId,
        'runId': 'post-fix',
        'hypothesisId': hypothesisId,
        'location': location,
        'msg': '[DEBUG] $message',
        'data': data,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }));
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  })();
}

class PocketMeowStore extends ChangeNotifier {
  PocketMeowStore({AppStorage? storage}) : _storage = storage ?? AppStorage() {
    autoBookkeepingService = AutoBookkeepingService(this);
  }

  static const String defaultBudgetBucketId = 'default';
  static const String otherBudgetBucketId = 'other';

  final AppStorage _storage;
  late final AutoBookkeepingService autoBookkeepingService;

  bool _isReady = false;
  bool _isAutoBookkeepingEnabled = false;
  double _totalBudget = 6000;
  int _budgetCycleStartDay = 1;
  List<BudgetPlan> _budgetPlans = const [];
  DateTime _selectedWeeklyDate = DateTime.now();
  DateTime _selectedMonthlyDate = DateTime.now();
  DateTime _selectedYearlyDate = DateTime.now();
  ReportType _reportType = ReportType.monthly;

  DateTime get _selectedDate {
    switch (_reportType) {
      case ReportType.weekly:
        return _selectedWeeklyDate;
      case ReportType.monthly:
        return _selectedMonthlyDate;
      case ReportType.yearly:
        return _selectedYearlyDate;
    }
  }

  set _selectedDate(DateTime date) {
    switch (_reportType) {
      case ReportType.weekly:
        _selectedWeeklyDate = date;
        break;
      case ReportType.monthly:
        _selectedMonthlyDate = date;
        break;
      case ReportType.yearly:
        _selectedYearlyDate = date;
        break;
    }
  }

  List<ExpenseCategory> _categories = const [];
  List<ExpenseRecord> _records = const [];

  bool get isReady => _isReady;
  bool get isAutoBookkeepingEnabled => _isAutoBookkeepingEnabled;
  double get totalBudget {
    return totalBudgetFor(_selectedBudgetReferenceDate);
  }

  int get budgetCycleStartDay => _budgetCycleStartDay;

  List<BudgetBucket> get budgetBuckets {
    final list = [...budgetBucketsFor(_selectedBudgetReferenceDate)];
    list.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) {
        return order;
      }
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(list);
  }

  List<BudgetBucketCategoryLink> get budgetBucketCategories =>
      List.unmodifiable(
          budgetBucketCategoriesFor(_selectedBudgetReferenceDate));

  Map<String, String> get budgetCategoryToBucket {
    final map = <String, String>{};
    for (final link in budgetBucketCategories) {
      map[link.categoryId] = link.bucketId;
    }
    return map;
  }

  DateTime get _selectedBudgetReferenceDate =>
      _reportType == ReportType.monthly ? _selectedDate : DateTime.now();

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
      _isAutoBookkeepingEnabled = snapshot.isAutoBookkeepingEnabled;
      _categories = snapshot.categories;
      _records = snapshot.expenses;
      _budgetCycleStartDay = snapshot.budgetCycleStartDay.clamp(1, 28);
      _budgetPlans = snapshot.budgetPlans;

      // Ensure new default categories exist for existing users
      bool needsPersist = false;
      if (!_categories.any((c) => c.id == 'transfer')) {
        _categories = [
          ..._categories,
          const ExpenseCategory(
            id: 'transfer',
            name: '转账',
            colorValue: 0xFF4A90E2,
            iconKey: 'wallet',
            limit: 0,
            type: RecordType.income,
            isSystem: true,
          )
        ];
        needsPersist = true;
      }
      if (!_categories.any((c) => c.id == 'rent')) {
        _categories = [
          ..._categories,
          const ExpenseCategory(
            id: 'rent',
            name: '房租',
            colorValue: 0xFF4DB6AC,
            iconKey: 'home',
            limit: 0,
            type: RecordType.expense,
            isSystem: true,
          )
        ];
        needsPersist = true;
      }
      if (!_categories.any((c) => c.id == 'living_expenses')) {
        _categories = [
          ..._categories,
          const ExpenseCategory(
            id: 'living_expenses',
            name: '生活缴费',
            colorValue: 0xFF81C784,
            iconKey: 'electric_bolt',
            limit: 0,
            type: RecordType.expense,
            isSystem: true,
          )
        ];
        needsPersist = true;
      }
      if (!_categories.any((c) => c.id == 'refund')) {
        _categories = [
          ..._categories,
          const ExpenseCategory(
            id: 'refund',
            name: '退款',
            colorValue: 0xFF81C784,
            iconKey: 'wallet',
            limit: 0,
            type: RecordType.income,
            isSystem: true,
          )
        ];
        needsPersist = true;
      }
      if (!_categories.any((c) => c.id == 'transfer_out')) {
        _categories = [
          ..._categories,
          const ExpenseCategory(
            id: 'transfer_out',
            name: '转账',
            colorValue: 0xFF4A90E2,
            iconKey: 'wallet',
            limit: 0,
            type: RecordType.expense,
            isSystem: true,
          )
        ];
        needsPersist = true;
      }

      // Update salary color if it is the old color
      final salaryIdx = _categories.indexWhere((c) => c.id == 'salary');
      if (salaryIdx != -1 && _categories[salaryIdx].colorValue == 0xFF143D35) {
        final newCategories = [..._categories];
        newCategories[salaryIdx] =
            newCategories[salaryIdx].copyWith(colorValue: 0xFFFF9800);
        _categories = newCategories;
        needsPersist = true;
      }

      if (_budgetPlans.isEmpty) {
        _budgetPlans = [
          _createDefaultBudgetPlan(budgetPeriodStartFor(DateTime.now()))
        ];
        needsPersist = true;
      } else if (_budgetPlans.any((plan) =>
          !plan.buckets.any((item) => item.id == otherBudgetBucketId))) {
        _budgetPlans = _budgetPlans
            .map(
              (plan) => plan.copyWith(
                buckets: [
                  ...plan.buckets,
                  const BudgetBucket(
                    id: otherBudgetBucketId,
                    name: '其它',
                    colorValue: 0xFFB0BEC5,
                    limitValue: 0,
                    sortOrder: 999,
                    isSystem: true,
                  ),
                ],
              ),
            )
            .toList();
        needsPersist = true;
      }

      if (needsPersist) {
        await _persist();
      }
    }

    if (_isAutoBookkeepingEnabled) {
      unawaited(autoBookkeepingService.startListening());
    }

    _isReady = true;
    notifyListeners();
  }

  List<ExpenseCategory> categoriesForType(RecordType type) {
    final matches = _categories.where((item) => item.type == type).toList();
    final originalOrder = <String, int>{
      for (var index = 0; index < _categories.length; index++)
        _categories[index].id: index,
    };
    int priorityFor(ExpenseCategory category) {
      if (type == RecordType.expense && category.id == 'daily') {
        return 0;
      }
      return category.isSystem ? 1 : 2;
    }

    matches.sort((a, b) {
      final priorityCompare = priorityFor(a).compareTo(priorityFor(b));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return (originalOrder[a.id] ?? 1 << 20)
          .compareTo(originalOrder[b.id] ?? 1 << 20);
    });
    return matches;
  }

  DateTimeRange monthlyBudgetRangeFor(DateTime date) {
    final startDay = _budgetCycleStartDay.clamp(1, 28);
    final start = date.day >= startDay
        ? DateTime(date.year, date.month, startDay)
        : DateTime(date.year, date.month - 1, startDay);
    final end = DateTime(start.year, start.month + 1, startDay);
    return DateTimeRange(start: start, end: end);
  }

  DateTime budgetPeriodStartFor(DateTime date) =>
      monthlyBudgetRangeFor(date).start;

  List<BudgetPlan> get _sortedBudgetPlans {
    final list = [..._budgetPlans];
    list.sort((a, b) => a.periodStart.compareTo(b.periodStart));
    return list;
  }

  BudgetPlan _createDefaultBudgetPlan(DateTime periodStart) {
    final buckets = [
      BudgetBucket(
        id: defaultBudgetBucketId,
        name: '默认预算',
        colorValue: 0xFF4DB6AC,
        limitValue: _totalBudget,
        sortOrder: 0,
        isSystem: false,
      ),
      const BudgetBucket(
        id: otherBudgetBucketId,
        name: '其它',
        colorValue: 0xFFB0BEC5,
        limitValue: 0,
        sortOrder: 999,
        isSystem: true,
      ),
    ];
    final links = _categories
        .where((item) => item.type == RecordType.expense)
        .map(
          (item) => BudgetBucketCategoryLink(
            bucketId: defaultBudgetBucketId,
            categoryId: item.id,
          ),
        )
        .toList();
    return BudgetPlan(
      periodStart: periodStart,
      buckets: buckets,
      bucketCategories: links,
    );
  }

  BudgetPlan budgetPlanFor(DateTime date) {
    final periodStart = budgetPeriodStartFor(date);
    final plans = _sortedBudgetPlans;
    if (plans.isEmpty) {
      return _createDefaultBudgetPlan(periodStart);
    }

    BudgetPlan? latestBeforeOrAt;
    for (final plan in plans) {
      if (!plan.periodStart.isAfter(periodStart)) {
        latestBeforeOrAt = plan;
        continue;
      }
      break;
    }

    return (latestBeforeOrAt ?? plans.first).copyWith(periodStart: periodStart);
  }

  BudgetPlan _ensureEditableBudgetPlan(DateTime date) {
    final periodStart = budgetPeriodStartFor(date);
    final existingIndex =
        _budgetPlans.indexWhere((item) => item.periodStart == periodStart);
    if (existingIndex != -1) {
      return _budgetPlans[existingIndex];
    }
    final plan = budgetPlanFor(date).copyWith(periodStart: periodStart);
    _budgetPlans = [..._budgetPlans, plan]
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
    return plan;
  }

  void _saveBudgetPlan(BudgetPlan plan) {
    final index =
        _budgetPlans.indexWhere((item) => item.periodStart == plan.periodStart);
    if (index == -1) {
      _budgetPlans = [..._budgetPlans, plan]
        ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
    } else {
      final next = [..._budgetPlans];
      next[index] = plan;
      _budgetPlans = next
        ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
    }
  }

  List<BudgetBucket> budgetBucketsFor(DateTime date) {
    final list = [...budgetPlanFor(date).buckets];
    list.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) {
        return order;
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  List<BudgetBucketCategoryLink> budgetBucketCategoriesFor(DateTime date) {
    return [...budgetPlanFor(date).bucketCategories];
  }

  Map<String, String> budgetCategoryToBucketFor(DateTime date) {
    final map = <String, String>{};
    for (final link in budgetBucketCategoriesFor(date)) {
      map[link.categoryId] = link.bucketId;
    }
    return map;
  }

  double totalBudgetFor(DateTime date) {
    final buckets = budgetBucketsFor(date);
    if (buckets.isEmpty) {
      return _totalBudget;
    }
    return buckets.fold(0.0, (sum, item) => sum + item.limitValue);
  }

  double budgetConsumedFor(DateTime date) {
    return recordsForMonth(date)
        .where((item) =>
            item.type == RecordType.expense && !item.excludeFromBudget)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double remainingBudgetFor(DateTime date) {
    return totalBudgetFor(date) - budgetConsumedFor(date);
  }

  List<BudgetBucketSpendData> budgetBucketSpendDataFor(DateTime date) {
    final buckets = budgetBucketsFor(date);
    final consumedMap = <String, double>{
      for (final bucket in buckets) bucket.id: 0
    };
    final categoryToBucket = budgetCategoryToBucketFor(date);
    for (final item in recordsForMonth(date)) {
      if (item.type != RecordType.expense || item.excludeFromBudget) {
        continue;
      }
      final bucketId = categoryToBucket[item.categoryId] ?? otherBudgetBucketId;
      consumedMap[bucketId] = (consumedMap[bucketId] ?? 0) + item.amount;
    }
    return buckets
        .map(
          (bucket) => BudgetBucketSpendData(
            bucket: bucket,
            consumed: consumedMap[bucket.id] ?? 0,
          ),
        )
        .toList();
  }

  List<ExpenseRecord> recordsForMonth(DateTime month) {
    final range = monthlyBudgetRangeFor(month);
    return _sortedRecords
        .where(
          (item) =>
              !item.createdAt.isBefore(range.start) &&
              item.createdAt.isBefore(range.end),
        )
        .toList();
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
        final range = monthlyBudgetRangeFor(date);
        return !item.createdAt.isBefore(range.start) &&
            item.createdAt.isBefore(range.end);
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
    if (_reportType != type) {
      _reportType = type;
      notifyListeners();
    }
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

  double get monthIncome => currentMonthIncomes
      .where((item) => !item.excludeFromBudget)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get monthNet => monthIncome - monthSpent;

  double get budgetConsumed => currentMonthExpenses
      .where((item) => !item.excludeFromBudget)
      .fold(0.0, (sum, item) => sum + item.amount);

  double monthSpentFor(DateTime month) =>
      monthAmountOf(RecordType.expense, month: month);

  double monthIncomeFor(DateTime month) =>
      recordsForType(RecordType.income, month: month)
          .where((item) => !item.excludeFromBudget)
          .fold(0.0, (sum, item) => sum + item.amount);

  double get remainingBudget => totalBudget - budgetConsumed;

  double get forecastEndOfMonth {
    final range = monthlyBudgetRangeFor(_selectedDate);
    final daysInMonth = range.duration.inDays;
    final referenceDay = _forecastReferenceDay;
    final dailyAverage =
        referenceDay == 0 ? 0.0 : budgetConsumed / referenceDay;
    return dailyAverage * daysInMonth;
  }

  double get projectedBalance => totalBudget - forecastEndOfMonth;

  double get budgetUsage {
    if (totalBudget <= 0) {
      return 0;
    }
    return (budgetConsumed / totalBudget).clamp(0.0, 1.0);
  }

  int _uuidCounter = 0;

  void addRecord({
    required double amount,
    required String categoryId,
    required String note,
    required RecordType type,
    DateTime? createdAt,
    bool excludeFromBudget = false,
    RecordSource? source,
    bool isManuallyEdited = false,
  }) {
    if (amount <= 0) {
      return;
    }
    final actualTime = createdAt ?? DateTime.now();
    final normalizedNote = _normalizeDedupNote(note);
    // 检查是否重复：金额、类型、备注一致，且时间差在 1 分钟内。
    final isDuplicate = _records.any((item) =>
        item.amount == amount &&
        item.type == type &&
        _normalizeDedupNote(item.note) == normalizedNote &&
        item.createdAt.difference(actualTime).inMinutes.abs() < 1);

    if (isDuplicate) {
      return;
    }

    _uuidCounter++;
    final record = ExpenseRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}_$_uuidCounter',
      amount: amount,
      categoryId: categoryId,
      note: note,
      createdAt: actualTime,
      type: type,
      excludeFromBudget: excludeFromBudget,
      source: source,
      isManuallyEdited: isManuallyEdited,
    );
    _records = [..._records, record];
    _persist();
    notifyListeners();
  }

  String _normalizeDedupNote(String note) {
    return note.trim();
  }

  void addExpense({
    required double amount,
    required String categoryId,
    required String note,
    DateTime? createdAt,
    bool excludeFromBudget = false,
  }) {
    addRecord(
      amount: amount,
      categoryId: categoryId,
      note: note,
      type: RecordType.expense,
      createdAt: createdAt,
      excludeFromBudget: excludeFromBudget,
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
    bool? excludeFromBudget,
    bool markAsManuallyEdited = true,
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
                  excludeFromBudget:
                      excludeFromBudget ?? item.excludeFromBudget,
                  isManuallyEdited:
                      markAsManuallyEdited ? true : item.isManuallyEdited,
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

  void setAutoBookkeepingEnabled(bool enabled) {
    if (_isAutoBookkeepingEnabled == enabled) {
      return;
    }
    _isAutoBookkeepingEnabled = enabled;
    _persist();
    notifyListeners();

    if (enabled) {
      unawaited(autoBookkeepingService.startListening());
    } else {
      autoBookkeepingService.stopListening();
    }
  }

  Future<void> refreshAutoBookkeepingListening() async {
    // #region debug-point A:refresh-auto-bookkeeping
    _reportStoreDebugEvent(
      hypothesisId: 'A',
      location: 'pocket_meow_store.dart:refreshAutoBookkeepingListening',
      message: 'Refreshing auto bookkeeping listening state',
      data: {
        'enabled': _isAutoBookkeepingEnabled,
        'ready': _isReady,
      },
    );
    // #endregion
    if (!_isAutoBookkeepingEnabled) return;
    await autoBookkeepingService.syncListeningWithPermissions();
    // #region debug-point A:refresh-auto-bookkeeping-done
    _reportStoreDebugEvent(
      hypothesisId: 'A',
      location: 'pocket_meow_store.dart:refreshAutoBookkeepingListening',
      message: 'Finished refreshing auto bookkeeping listening state',
      data: {
        'serviceIsListening': autoBookkeepingService.isListening,
      },
    );
    // #endregion
  }

  @override
  void dispose() {
    autoBookkeepingService.stopListening();
    super.dispose();
  }

  void updateTotalBudget(double value, {DateTime? targetDate}) {
    final date = targetDate ?? _selectedBudgetReferenceDate;
    final plan = _ensureEditableBudgetPlan(date);
    final buckets = [...plan.buckets];
    final index =
        buckets.indexWhere((item) => item.id == defaultBudgetBucketId);
    if (index == -1) {
      return;
    }
    buckets[index] = buckets[index].copyWith(limitValue: value);
    _saveBudgetPlan(plan.copyWith(buckets: buckets));
    notifyListeners();
    _persist();
  }

  BudgetBucket? budgetBucketById(String id, {DateTime? targetDate}) {
    for (final item
        in budgetBucketsFor(targetDate ?? _selectedBudgetReferenceDate)) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  void setBudgetCycleStartDay(int day) {
    final next = day.clamp(1, 28);
    if (_budgetCycleStartDay == next) {
      return;
    }
    _budgetCycleStartDay = next;
    notifyListeners();
    _persist();
  }

  void addBudgetBucket({
    required String name,
    required double limitValue,
    required int colorValue,
    DateTime? targetDate,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final date = targetDate ?? _selectedBudgetReferenceDate;
    final plan = _ensureEditableBudgetPlan(date);
    final currentBuckets = [...plan.buckets];
    final id = 'bucket_${DateTime.now().microsecondsSinceEpoch}';
    final maxOrder = currentBuckets.where((item) => !item.isSystem).fold<int>(0,
        (maxValue, item) {
      if (item.sortOrder > maxValue) {
        return item.sortOrder;
      }
      return maxValue;
    });
    final otherOrder = currentBuckets
        .where((item) => item.id == otherBudgetBucketId)
        .map((item) => item.sortOrder)
        .fold<int>(999, (a, b) => b);
    final nextOrder =
        (maxOrder + 1) >= otherOrder ? otherOrder - 1 : maxOrder + 1;
    final bucket = BudgetBucket(
      id: id,
      name: trimmed,
      colorValue: colorValue,
      limitValue: limitValue,
      sortOrder: nextOrder,
      isSystem: false,
    );
    _saveBudgetPlan(plan.copyWith(buckets: [...currentBuckets, bucket]));
    notifyListeners();
    _persist();
  }

  void updateBudgetBucket(BudgetBucket bucket, {DateTime? targetDate}) {
    final date = targetDate ?? _selectedBudgetReferenceDate;
    final plan = _ensureEditableBudgetPlan(date);
    final buckets = [...plan.buckets];
    final index = buckets.indexWhere((item) => item.id == bucket.id);
    if (index == -1) {
      return;
    }
    buckets[index] = bucket;
    _saveBudgetPlan(plan.copyWith(buckets: buckets));
    notifyListeners();
    _persist();
  }

  void deleteBudgetBucket(String bucketId, {DateTime? targetDate}) {
    final date = targetDate ?? _selectedBudgetReferenceDate;
    final plan = _ensureEditableBudgetPlan(date);
    final bucket = budgetBucketById(bucketId, targetDate: date);
    if (bucket == null || bucket.isSystem) {
      return;
    }
    final buckets = plan.buckets.where((item) => item.id != bucketId).toList();
    final links = plan.bucketCategories
        .where((item) => item.bucketId != bucketId)
        .toList();
    _saveBudgetPlan(plan.copyWith(
      buckets: buckets,
      bucketCategories: links,
    ));
    notifyListeners();
    _persist();
  }

  void setBudgetBucketCategoriesForBucket(
      String bucketId, Set<String> categoryIds,
      {DateTime? targetDate}) {
    final date = targetDate ?? _selectedBudgetReferenceDate;
    final plan = _ensureEditableBudgetPlan(date);
    if (!plan.buckets.any((item) => item.id == bucketId)) {
      return;
    }

    final next = <BudgetBucketCategoryLink>[];
    for (final link in plan.bucketCategories) {
      if (link.bucketId == bucketId) {
        continue;
      }
      if (categoryIds.contains(link.categoryId)) {
        continue;
      }
      next.add(link);
    }

    for (final categoryId in categoryIds) {
      next.add(
        BudgetBucketCategoryLink(
          bucketId: bucketId,
          categoryId: categoryId,
        ),
      );
    }

    _saveBudgetPlan(plan.copyWith(bucketCategories: next));
    notifyListeners();
    _persist();
  }

  List<BudgetBucketSpendData> get budgetBucketSpendData =>
      budgetBucketSpendDataFor(_selectedBudgetReferenceDate);

  void addCategory({
    required String name,
    required RecordType type,
    required String iconKey,
    required int colorValue,
    double? limit,
  }) {
    if (name.isEmpty) {
      return;
    }
    final category = ExpenseCategory(
      id: '${type.key}_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colorValue: colorValue,
      iconKey: iconKey,
      limit: limit ?? 0,
      type: type,
      isSystem: false,
    );
    _categories = [..._categories, category];
    _persist();
    notifyListeners();
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
      _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
    } else if (_reportType == ReportType.monthly) {
      _selectedDate = DateTime(
          _selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
    } else {
      _selectedDate = _selectedDate.subtract(const Duration(days: 7));
    }
    notifyListeners();
  }

  void goToNextMonth() {
    final now = DateTime.now();
    if (_reportType == ReportType.yearly) {
      if (_selectedDate.year < now.year) {
        _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
      }
    } else if (_reportType == ReportType.monthly) {
      if (_selectedDate.year < now.year ||
          (_selectedDate.year == now.year && _selectedDate.month < now.month)) {
        _selectedDate = DateTime(
            _selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
      }
    } else {
      final startOfCurrentWeek =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final startOfNowWeek = now.subtract(Duration(days: now.weekday - 1));
      if (startOfCurrentWeek.isBefore(startOfNowWeek)) {
        _selectedDate = _selectedDate.add(const Duration(days: 7));
      }
    }
    notifyListeners();
  }

  void resetDemoData() {
    _seedInitialData();
    notifyListeners();
    _persist();
  }

  Future<String> exportData() async {
    final snapshot = _snapshot;
    return jsonEncode(snapshot.toJson());
  }

  Future<void> importData(String jsonStr) async {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final snapshot = AppSnapshot.fromJson(map);
    _totalBudget = snapshot.totalBudget;
    _isAutoBookkeepingEnabled = snapshot.isAutoBookkeepingEnabled;
    _categories = snapshot.categories;
    _records = snapshot.expenses;
    _budgetCycleStartDay = snapshot.budgetCycleStartDay.clamp(1, 28);
    _budgetPlans = snapshot.budgetPlans;
    notifyListeners();
    await _persist();
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

  int countForCategory(
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
        .length;
  }

  List<CategorySpendData> categoryDataForType(RecordType type) {
    final records = currentMonthRecords
        .where((item) => item.type == type && !item.excludeFromBudget);
    final amountMap = <String, double>{};
    final countMap = <String, int>{};

    for (final item in records) {
      amountMap[item.categoryId] =
          (amountMap[item.categoryId] ?? 0) + item.amount;
      countMap[item.categoryId] = (countMap[item.categoryId] ?? 0) + 1;
    }

    final list = categoriesForType(type)
        .map(
          (category) => CategorySpendData(
            category: category,
            amount: amountMap[category.id] ?? 0.0,
            count: countMap[category.id] ?? 0,
          ),
        )
        .where((item) => item.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  List<CategorySpendData> get categorySpendData {
    // Also include transfer type in expenses if user selected it for expense
    // Actually, to make '转账' visible in chart, we should query all records or just map them properly.
    // Wait, the user mentioned "转账" wasn't included in the analysis chart.
    // This is because '转账' is currently defined as an income type (RecordType.income) in _categories!
    // Let's modify categorySpendData to also check for RecordType.income if they are used as expenses,
    // OR we should just get all categories that have expenses.
    final records = currentMonthExpenses;
    final amountMap = <String, double>{};
    final countMap = <String, int>{};

    for (final item in records) {
      amountMap[item.categoryId] =
          (amountMap[item.categoryId] ?? 0) + item.amount;
      countMap[item.categoryId] = (countMap[item.categoryId] ?? 0) + 1;
    }

    final list = _categories
        .map(
          (category) => CategorySpendData(
            category: category,
            amount: amountMap[category.id] ?? 0.0,
            count: countMap[category.id] ?? 0,
          ),
        )
        .where((item) => item.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  List<TrendPointData> get periodTrendData {
    final items = <TrendPointData>[];
    final expenses =
        currentMonthExpenses.where((e) => !e.excludeFromBudget).toList();
    final incomes =
        currentMonthIncomes.where((i) => !i.excludeFromBudget).toList();

    if (_reportType == ReportType.yearly) {
      // Group by month
      final expenseMap = <int, double>{};
      final incomeMap = <int, double>{};
      for (int i = 1; i <= 12; i++) {
        expenseMap[i] = 0;
        incomeMap[i] = 0;
      }
      for (final item in expenses) {
        expenseMap[item.createdAt.month] =
            (expenseMap[item.createdAt.month] ?? 0) + item.amount;
      }
      for (final item in incomes) {
        incomeMap[item.createdAt.month] =
            (incomeMap[item.createdAt.month] ?? 0) + item.amount;
      }
      for (int i = 1; i <= 12; i++) {
        items.add(TrendPointData(
            label: '$i月', expense: expenseMap[i]!, income: incomeMap[i]!));
      }
    } else if (_reportType == ReportType.monthly) {
      final range = monthlyBudgetRangeFor(_selectedDate);
      final daysInPeriod = range.duration.inDays;
      final expenseMap = <int, double>{};
      final incomeMap = <int, double>{};
      for (int i = 0; i < daysInPeriod; i++) {
        expenseMap[i] = 0;
        incomeMap[i] = 0;
      }
      for (final item in expenses) {
        final offset = DateTime(
          item.createdAt.year,
          item.createdAt.month,
          item.createdAt.day,
        ).difference(range.start).inDays;
        if (offset < 0 || offset >= daysInPeriod) {
          continue;
        }
        expenseMap[offset] = (expenseMap[offset] ?? 0) + item.amount;
      }
      for (final item in incomes) {
        final offset = DateTime(
          item.createdAt.year,
          item.createdAt.month,
          item.createdAt.day,
        ).difference(range.start).inDays;
        if (offset < 0 || offset >= daysInPeriod) {
          continue;
        }
        incomeMap[offset] = (incomeMap[offset] ?? 0) + item.amount;
      }
      for (int i = 0; i < daysInPeriod; i++) {
        final day = range.start.add(Duration(days: i));
        items.add(
          TrendPointData(
            label: '${day.month}/${day.day}',
            expense: expenseMap[i] ?? 0,
            income: incomeMap[i] ?? 0,
          ),
        );
      }
    } else {
      final expenseMap = <int, double>{};
      final incomeMap = <int, double>{};
      for (int i = 1; i <= 7; i++) {
        expenseMap[i] = 0;
        incomeMap[i] = 0;
      }
      for (final item in expenses) {
        expenseMap[item.createdAt.weekday] =
            (expenseMap[item.createdAt.weekday] ?? 0) + item.amount;
      }
      for (final item in incomes) {
        incomeMap[item.createdAt.weekday] =
            (incomeMap[item.createdAt.weekday] ?? 0) + item.amount;
      }
      final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      for (int i = 1; i <= 7; i++) {
        items.add(TrendPointData(
            label: '周${weekdays[i - 1]}',
            expense: expenseMap[i]!,
            income: incomeMap[i]!));
      }
    }

    return items;
  }

  List<DailySpendData> get recentDailySpend {
    final anchor = _recentTrendAnchor;
    final items = <DailySpendData>[];

    final expenses =
        currentMonthExpenses.where((e) => !e.excludeFromBudget).toList();
    final incomes =
        currentMonthIncomes.where((i) => !i.excludeFromBudget).toList();

    for (var i = 6; i >= 0; i--) {
      final day = DateTime(anchor.year, anchor.month, anchor.day - i);
      double exp = 0;
      double inc = 0;
      for (final e in expenses) {
        if (e.createdAt.day == day.day &&
            e.createdAt.month == day.month &&
            e.createdAt.year == day.year) {
          exp += e.amount;
        }
      }
      for (final e in incomes) {
        if (e.createdAt.day == day.day &&
            e.createdAt.month == day.month &&
            e.createdAt.year == day.year) {
          inc += e.amount;
        }
      }
      items.add(DailySpendData(date: day, expense: exp, income: inc));
    }
    return items;
  }

  List<MonthSpendData> get historyBarData {
    final items = <MonthSpendData>[];

    // Filter out excluded records early
    final validRecords =
        _sortedRecords.where((r) => !r.excludeFromBudget).toList();

    if (_reportType == ReportType.weekly) {
      // 周报: 该周每日的消费
      final startOfWeek =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      for (var i = 0; i < 7; i++) {
        items.add(
            MonthSpendData(label: '周${weekdays[i]}', expense: 0, income: 0));
      }
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      for (final item in validRecords) {
        if (item.createdAt.isBefore(startOfWeek)) {
          break;
        }
        if (item.createdAt.isAfter(endOfWeek.add(const Duration(days: 1)))) {
          continue;
        }
        final dayIndex = item.createdAt.weekday - 1;
        if (item.type == RecordType.expense) {
          items[dayIndex].expense += item.amount;
        } else {
          items[dayIndex].income += item.amount;
        }
      }
    } else if (_reportType == ReportType.monthly) {
      final range = monthlyBudgetRangeFor(_selectedDate);
      final daysInPeriod = range.duration.inDays;
      final weekCount = (daysInPeriod / 7).ceil().clamp(1, 6);
      for (var i = 0; i < weekCount; i++) {
        items.add(MonthSpendData(label: '第${i + 1}周', expense: 0, income: 0));
      }

      for (final item in validRecords) {
        if (item.createdAt.isBefore(range.start)) {
          continue;
        }
        if (!item.createdAt.isBefore(range.end)) {
          continue;
        }
        final itemDate = DateTime(
          item.createdAt.year,
          item.createdAt.month,
          item.createdAt.day,
        );
        final offset = itemDate.difference(range.start).inDays;
        final weekIndex = (offset ~/ 7).clamp(0, items.length - 1);
        if (item.type == RecordType.expense) {
          items[weekIndex].expense += item.amount;
        } else {
          items[weekIndex].income += item.amount;
        }
      }
    } else if (_reportType == ReportType.yearly) {
      // 年报: 每月的消费
      for (var i = 1; i <= 12; i++) {
        items.add(MonthSpendData(label: '$i月', expense: 0, income: 0));
      }
      final firstDayOfYear = DateTime(_selectedDate.year, 1, 1);
      final lastDayOfYear = DateTime(_selectedDate.year, 12, 31);
      for (final item in validRecords) {
        if (item.createdAt.isBefore(firstDayOfYear)) {
          break;
        }
        if (item.createdAt
            .isAfter(lastDayOfYear.add(const Duration(days: 1)))) {
          continue;
        }
        final monthIndex = item.createdAt.month - 1;
        if (item.type == RecordType.expense) {
          items[monthIndex].expense += item.amount;
        } else {
          items[monthIndex].income += item.amount;
        }
      }
    }

    return items;
  }

  // --- Previous Period Comparison ---
  double get previousPeriodExpense {
    final prevRecords = _getPreviousPeriodRecords();
    return prevRecords
        .where((r) => r.type == RecordType.expense && !r.excludeFromBudget)
        .fold(0.0, (sum, r) => sum + r.amount);
  }

  double get previousPeriodIncome {
    final prevRecords = _getPreviousPeriodRecords();
    return prevRecords
        .where((r) => r.type == RecordType.income && !r.excludeFromBudget)
        .fold(0.0, (sum, r) => sum + r.amount);
  }

  double get previousPeriodNet => previousPeriodIncome - previousPeriodExpense;

  List<ExpenseRecord> _getPreviousPeriodRecords() {
    final d = _selectedDate;
    switch (_reportType) {
      case ReportType.weekly:
        // 上一周
        final prevWeek = d.subtract(const Duration(days: 7));
        final start = prevWeek.subtract(Duration(days: prevWeek.weekday - 1));
        final end = start
            .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return _records
            .where((r) =>
                r.createdAt
                    .isAfter(start.subtract(const Duration(seconds: 1))) &&
                r.createdAt.isBefore(end.add(const Duration(seconds: 1))))
            .toList();
      case ReportType.monthly:
        // 上一个预算周期（月度视图受预算周期起始日影响）
        final prevMonth = DateTime(d.year, d.month - 1, d.day);
        final range = monthlyBudgetRangeFor(prevMonth);
        return _records
            .where((r) =>
                !r.createdAt.isBefore(range.start) &&
                r.createdAt.isBefore(range.end))
            .toList();
      case ReportType.yearly:
        // 上一年
        final prevYear = DateTime(d.year - 1);
        return _records
            .where((r) => r.createdAt.year == prevYear.year)
            .toList();
    }
  }

  String get primaryInsight {
    if (currentMonthRecords.isEmpty) {
      return '还没有账单，先记下第一笔收入或支出，钱喵就能开始分析你的现金流。';
    }

    if (totalBudget > 0 && budgetConsumed > totalBudget) {
      final overBy = budgetConsumed - totalBudget;
      return '本月总支出已超出预算 ${overBy.toStringAsFixed(0)} 元，建议先控制大额消费。';
    }

    if (totalBudget > 0 && budgetUsage >= 0.85) {
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
    final previous = DateTime(
        _selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
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
    final selectedPlan = budgetPlanFor(_selectedBudgetReferenceDate);
    return AppSnapshot(
      totalBudget: totalBudget,
      isAutoBookkeepingEnabled: _isAutoBookkeepingEnabled,
      categories: _categories,
      expenses: _records,
      budgetCycleStartDay: _budgetCycleStartDay,
      budgetBuckets: selectedPlan.buckets,
      budgetBucketCategories: selectedPlan.bucketCategories,
      budgetPlans: _budgetPlans,
    );
  }

  Future<void> _persist() async {
    await _storage.saveSnapshot(_snapshot);
  }

  DateTime get _recentTrendAnchor {
    final now = DateTime.now();
    if (_reportType != ReportType.monthly) {
      final isCurrentMonth =
          _selectedDate.year == now.year && _selectedDate.month == now.month;
      if (isCurrentMonth) {
        return DateTime(now.year, now.month, now.day);
      }
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      return DateTime(lastDay.year, lastDay.month, lastDay.day);
    }

    final range = monthlyBudgetRangeFor(_selectedDate);
    final anchor = DateTime(now.year, now.month, now.day);
    final endInclusive = range.end.subtract(const Duration(days: 1));
    if (!anchor.isBefore(range.start) && !anchor.isAfter(endInclusive)) {
      return anchor;
    }
    return DateTime(endInclusive.year, endInclusive.month, endInclusive.day);
  }

  int get _forecastReferenceDay {
    final now = DateTime.now();
    if (_reportType != ReportType.monthly) {
      final isCurrentMonth =
          _selectedDate.year == now.year && _selectedDate.month == now.month;
      if (isCurrentMonth) {
        return now.day;
      }
      return DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    }

    final range = monthlyBudgetRangeFor(_selectedDate);
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(range.start)) {
      return 0;
    }
    if (today.isAfter(range.end.subtract(const Duration(days: 1)))) {
      return range.duration.inDays;
    }
    return today.difference(range.start).inDays + 1;
  }

  void _seedInitialData() {
    _totalBudget = 6000;
    _categories = const [
      ExpenseCategory(
          id: 'daily',
          name: '日用',
          colorValue: 0xFFFFB74D,
          iconKey: 'local_mall',
          limit: 500,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'food',
          name: '餐饮',
          colorValue: 0xFFE57373,
          iconKey: 'restaurant',
          limit: 1500,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'transport',
          name: '交通',
          colorValue: 0xFF81C784,
          iconKey: 'directions_bus',
          limit: 500,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'shopping',
          name: '购物',
          colorValue: 0xFF64B5F6,
          iconKey: 'shopping_cart',
          limit: 1000,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'entertainment',
          name: '娱乐',
          colorValue: 0xFF9575CD,
          iconKey: 'sports_esports',
          limit: 800,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'medical',
          name: '医疗',
          colorValue: 0xFF4DD0E1,
          iconKey: 'medical_services',
          limit: 500,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'rent',
          name: '房租',
          colorValue: 0xFF4DB6AC,
          iconKey: 'home',
          limit: 0,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'living_expenses',
          name: '生活缴费',
          colorValue: 0xFF81C784,
          iconKey: 'electric_bolt',
          limit: 0,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'transfer_out',
          name: '转账',
          colorValue: 0xFF4A90E2,
          iconKey: 'wallet',
          limit: 0,
          type: RecordType.expense,
          isSystem: true),
      ExpenseCategory(
          id: 'salary',
          name: '工资',
          colorValue: 0xFFFF9800,
          iconKey: 'payments',
          limit: 0,
          type: RecordType.income,
          isSystem: true),
      ExpenseCategory(
          id: 'bonus',
          name: '奖金',
          colorValue: 0xFFFFD54F,
          iconKey: 'card_giftcard',
          limit: 0,
          type: RecordType.income,
          isSystem: true),
      ExpenseCategory(
          id: 'investment',
          name: '理财',
          colorValue: 0xFF4FC3F7,
          iconKey: 'trending_up',
          limit: 0,
          type: RecordType.income,
          isSystem: true),
      ExpenseCategory(
          id: 'refund',
          name: '退款',
          colorValue: 0xFF81C784,
          iconKey: 'wallet',
          limit: 0,
          type: RecordType.income,
          isSystem: true),
      ExpenseCategory(
          id: 'transfer',
          name: '转账',
          colorValue: 0xFF4A90E2,
          iconKey: 'wallet',
          limit: 0,
          type: RecordType.income,
          isSystem: true),
    ];
    _budgetCycleStartDay = 1;
    final initialPlan =
        _createDefaultBudgetPlan(budgetPeriodStartFor(DateTime.now()));
    _budgetPlans = [initialPlan];
    _records = const [];
  }
}

class CategorySpendData {
  CategorySpendData({
    required this.category,
    required this.amount,
    required this.count,
  });

  final ExpenseCategory category;
  final double amount;
  final int count;

  double shareOf(double total) {
    if (total <= 0) {
      return 0;
    }
    return amount / total;
  }
}

class TrendPointData {
  TrendPointData({
    required this.label,
    required this.expense,
    required this.income,
  });

  final String label;
  final double expense;
  final double income;
}

class BudgetBucketSpendData {
  BudgetBucketSpendData({
    required this.bucket,
    required this.consumed,
  });

  final BudgetBucket bucket;
  final double consumed;

  double get remaining => bucket.limitValue - consumed;
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
    required this.label,
    required this.expense,
    required this.income,
  });

  final String label;
  double expense;
  double income;

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
