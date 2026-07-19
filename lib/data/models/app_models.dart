enum RecordType {
  expense,
  income,
}

enum RecordSource {
  autoAlipay,
  autoWeChat,
}

extension RecordTypeX on RecordType {
  String get key {
    switch (this) {
      case RecordType.expense:
        return 'expense';
      case RecordType.income:
        return 'income';
    }
  }

  String get label {
    switch (this) {
      case RecordType.expense:
        return '支出';
      case RecordType.income:
        return '收入';
    }
  }

  static RecordType fromKey(String? key) {
    if (key == RecordType.income.key) {
      return RecordType.income;
    }
    return RecordType.expense;
  }
}

extension RecordSourceX on RecordSource {
  String get key {
    switch (this) {
      case RecordSource.autoAlipay:
        return 'auto_alipay';
      case RecordSource.autoWeChat:
        return 'auto_wechat';
    }
  }

  String get label {
    switch (this) {
      case RecordSource.autoAlipay:
        return '支付宝自动记账';
      case RecordSource.autoWeChat:
        return '微信自动记账';
    }
  }

  static RecordSource? fromKey(String? key) {
    switch (key) {
      case 'auto_alipay':
        return RecordSource.autoAlipay;
      case 'auto_wechat':
        return RecordSource.autoWeChat;
      default:
        return null;
    }
  }
}

class ExpenseRecord {
  ExpenseRecord({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.createdAt,
    required this.type,
    this.excludeFromBudget = false,
    this.source,
    this.isManuallyEdited = false,
  });

  final String id;
  final double amount;
  final String categoryId;
  final String note;
  final DateTime createdAt;
  final RecordType type;
  final bool excludeFromBudget;
  final RecordSource? source;
  final bool isManuallyEdited;

  ExpenseRecord copyWith({
    String? id,
    double? amount,
    String? categoryId,
    String? note,
    DateTime? createdAt,
    RecordType? type,
    bool? excludeFromBudget,
    RecordSource? source,
    bool? isManuallyEdited,
  }) {
    return ExpenseRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      excludeFromBudget: excludeFromBudget ?? this.excludeFromBudget,
      source: source ?? this.source,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'type': type.key,
      'excludeFromBudget': excludeFromBudget,
      'source': source?.key,
      'isManuallyEdited': isManuallyEdited,
    };
  }

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['categoryId'] as String,
      note: json['note'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: RecordTypeX.fromKey(json['type'] as String?),
      excludeFromBudget: json['excludeFromBudget'] as bool? ?? false,
      source: RecordSourceX.fromKey(json['source'] as String?),
      isManuallyEdited: json['isManuallyEdited'] as bool? ?? false,
    );
  }
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconKey,
    required this.limit,
    required this.type,
    required this.isSystem,
  });

  final String id;
  final String name;
  final int colorValue;
  final String iconKey;
  final double limit;
  final RecordType type;
  final bool isSystem;

  ExpenseCategory copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? iconKey,
    double? limit,
    RecordType? type,
    bool? isSystem,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      limit: limit ?? this.limit,
      type: type ?? this.type,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'iconKey': iconKey,
      'limit': limit,
      'type': type.key,
      'isSystem': isSystem,
    };
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int,
      iconKey: json['iconKey'] as String,
      limit: (json['limit'] as num).toDouble(),
      type: RecordTypeX.fromKey(json['type'] as String?),
      isSystem: json['isSystem'] as bool? ?? true,
    );
  }
}

class BudgetBucket {
  const BudgetBucket({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.limitValue,
    required this.sortOrder,
    required this.isSystem,
  });

  final String id;
  final String name;
  final int colorValue;
  final double limitValue;
  final int sortOrder;
  final bool isSystem;

  BudgetBucket copyWith({
    String? id,
    String? name,
    int? colorValue,
    double? limitValue,
    int? sortOrder,
    bool? isSystem,
  }) {
    return BudgetBucket(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      limitValue: limitValue ?? this.limitValue,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'limitValue': limitValue,
      'sortOrder': sortOrder,
      'isSystem': isSystem,
    };
  }

  factory BudgetBucket.fromJson(Map<String, dynamic> json) {
    return BudgetBucket(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int,
      limitValue: (json['limitValue'] as num).toDouble(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }
}

class BudgetBucketCategoryLink {
  const BudgetBucketCategoryLink({
    required this.bucketId,
    required this.categoryId,
  });

  final String bucketId;
  final String categoryId;

  Map<String, dynamic> toJson() {
    return {
      'bucketId': bucketId,
      'categoryId': categoryId,
    };
  }

  factory BudgetBucketCategoryLink.fromJson(Map<String, dynamic> json) {
    return BudgetBucketCategoryLink(
      bucketId: json['bucketId'] as String,
      categoryId: json['categoryId'] as String,
    );
  }
}

class BudgetPlan {
  const BudgetPlan({
    required this.periodStart,
    required this.buckets,
    required this.bucketCategories,
  });

  final DateTime periodStart;
  final List<BudgetBucket> buckets;
  final List<BudgetBucketCategoryLink> bucketCategories;

  BudgetPlan copyWith({
    DateTime? periodStart,
    List<BudgetBucket>? buckets,
    List<BudgetBucketCategoryLink>? bucketCategories,
  }) {
    return BudgetPlan(
      periodStart: periodStart ?? this.periodStart,
      buckets: buckets ?? this.buckets,
      bucketCategories: bucketCategories ?? this.bucketCategories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'periodStart': periodStart.toIso8601String(),
      'buckets': buckets.map((item) => item.toJson()).toList(),
      'bucketCategories':
          bucketCategories.map((item) => item.toJson()).toList(),
    };
  }

  factory BudgetPlan.fromJson(Map<String, dynamic> json) {
    return BudgetPlan(
      periodStart: DateTime.parse(json['periodStart'] as String),
      buckets: (json['buckets'] as List<dynamic>)
          .map((item) => BudgetBucket.fromJson(item as Map<String, dynamic>))
          .toList(),
      bucketCategories: (json['bucketCategories'] as List<dynamic>)
          .map((item) =>
              BudgetBucketCategoryLink.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AppSnapshot {
  AppSnapshot({
    required this.totalBudget,
    required this.categories,
    required this.expenses,
    this.budgetCycleStartDay = 1,
    this.budgetBuckets = const [],
    this.budgetBucketCategories = const [],
    this.budgetPlans = const [],
    this.isAutoBookkeepingEnabled = false,
  });

  final double totalBudget;
  final List<ExpenseCategory> categories;
  final List<ExpenseRecord> expenses;
  final int budgetCycleStartDay;
  final List<BudgetBucket> budgetBuckets;
  final List<BudgetBucketCategoryLink> budgetBucketCategories;
  final List<BudgetPlan> budgetPlans;
  final bool isAutoBookkeepingEnabled;

  Map<String, dynamic> toJson() {
    return {
      'totalBudget': totalBudget,
      'isAutoBookkeepingEnabled': isAutoBookkeepingEnabled,
      'categories': categories.map((item) => item.toJson()).toList(),
      'expenses': expenses.map((item) => item.toJson()).toList(),
      'budgetCycleStartDay': budgetCycleStartDay,
      'budgetBuckets': budgetBuckets.map((item) => item.toJson()).toList(),
      'budgetBucketCategories':
          budgetBucketCategories.map((item) => item.toJson()).toList(),
      'budgetPlans': budgetPlans.map((item) => item.toJson()).toList(),
    };
  }

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List<dynamic>)
        .map((item) => ExpenseCategory.fromJson(item as Map<String, dynamic>))
        .toList();

    final budgetCycleStartDay =
        (json['budgetCycleStartDay'] as num?)?.toInt() ?? 1;

    final budgetBuckets = (json['budgetBuckets'] as List<dynamic>?)
            ?.map((item) => BudgetBucket.fromJson(item as Map<String, dynamic>))
            .toList() ??
        const <BudgetBucket>[];

    final budgetBucketCategories = (json['budgetBucketCategories']
                as List<dynamic>?)
            ?.map((item) =>
                BudgetBucketCategoryLink.fromJson(item as Map<String, dynamic>))
            .toList() ??
        const <BudgetBucketCategoryLink>[];

    final budgetPlans = (json['budgetPlans'] as List<dynamic>?)
            ?.map((item) => BudgetPlan.fromJson(item as Map<String, dynamic>))
            .toList() ??
        const <BudgetPlan>[];

    final totalBudget = (json['totalBudget'] as num).toDouble();
    final now = DateTime.now();
    final legacyPeriodStart = now.day >= budgetCycleStartDay
        ? DateTime(now.year, now.month, budgetCycleStartDay)
        : DateTime(now.year, now.month - 1, budgetCycleStartDay);

    if (budgetPlans.isNotEmpty) {
      return AppSnapshot(
        totalBudget: totalBudget,
        isAutoBookkeepingEnabled:
            json['isAutoBookkeepingEnabled'] as bool? ?? false,
        categories: categories,
        expenses: (json['expenses'] as List<dynamic>)
            .map((item) => ExpenseRecord.fromJson(item as Map<String, dynamic>))
            .toList(),
        budgetCycleStartDay: budgetCycleStartDay,
        budgetBuckets: budgetBuckets,
        budgetBucketCategories: budgetBucketCategories,
        budgetPlans: budgetPlans,
      );
    }

    if (budgetBuckets.isEmpty) {
      const defaultBucketId = 'default';
      const otherBucketId = 'other';

      final mappedCategories = categories
          .where((item) => item.type == RecordType.expense)
          .map((item) => BudgetBucketCategoryLink(
                bucketId: defaultBucketId,
                categoryId: item.id,
              ))
          .toList();

      return AppSnapshot(
        totalBudget: totalBudget,
        isAutoBookkeepingEnabled:
            json['isAutoBookkeepingEnabled'] as bool? ?? false,
        categories: categories,
        expenses: (json['expenses'] as List<dynamic>)
            .map((item) => ExpenseRecord.fromJson(item as Map<String, dynamic>))
            .toList(),
        budgetCycleStartDay: budgetCycleStartDay,
        budgetBuckets: [
          BudgetBucket(
            id: defaultBucketId,
            name: '默认预算',
            colorValue: 0xFF4DB6AC,
            limitValue: totalBudget,
            sortOrder: 0,
            isSystem: false,
          ),
          const BudgetBucket(
            id: otherBucketId,
            name: '其它',
            colorValue: 0xFFB0BEC5,
            limitValue: 0,
            sortOrder: 999,
            isSystem: true,
          ),
        ],
        budgetBucketCategories: mappedCategories,
        budgetPlans: [
          BudgetPlan(
            periodStart: legacyPeriodStart,
            buckets: [
              BudgetBucket(
                id: defaultBucketId,
                name: '默认预算',
                colorValue: 0xFF4DB6AC,
                limitValue: totalBudget,
                sortOrder: 0,
                isSystem: false,
              ),
              const BudgetBucket(
                id: otherBucketId,
                name: '其它',
                colorValue: 0xFFB0BEC5,
                limitValue: 0,
                sortOrder: 999,
                isSystem: true,
              ),
            ],
            bucketCategories: mappedCategories,
          ),
        ],
      );
    }

    return AppSnapshot(
      totalBudget: totalBudget,
      isAutoBookkeepingEnabled:
          json['isAutoBookkeepingEnabled'] as bool? ?? false,
      categories: categories,
      expenses: (json['expenses'] as List<dynamic>)
          .map((item) => ExpenseRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      budgetCycleStartDay: budgetCycleStartDay,
      budgetBuckets: budgetBuckets,
      budgetBucketCategories: budgetBucketCategories,
      budgetPlans: [
        BudgetPlan(
          periodStart: legacyPeriodStart,
          buckets: budgetBuckets,
          bucketCategories: budgetBucketCategories,
        ),
      ],
    );
  }
}
