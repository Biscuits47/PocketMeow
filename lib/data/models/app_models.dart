enum RecordType {
  expense,
  income,
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

class ExpenseRecord {
  ExpenseRecord({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.createdAt,
    required this.type,
  });

  final String id;
  final double amount;
  final String categoryId;
  final String note;
  final DateTime createdAt;
  final RecordType type;

  ExpenseRecord copyWith({
    String? id,
    double? amount,
    String? categoryId,
    String? note,
    DateTime? createdAt,
    RecordType? type,
  }) {
    return ExpenseRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
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

class AppSnapshot {
  AppSnapshot({
    required this.totalBudget,
    required this.categories,
    required this.expenses,
  });

  final double totalBudget;
  final List<ExpenseCategory> categories;
  final List<ExpenseRecord> expenses;

  Map<String, dynamic> toJson() {
    return {
      'totalBudget': totalBudget,
      'categories': categories.map((item) => item.toJson()).toList(),
      'expenses': expenses.map((item) => item.toJson()).toList(),
    };
  }

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    return AppSnapshot(
      totalBudget: (json['totalBudget'] as num).toDouble(),
      categories: (json['categories'] as List<dynamic>)
          .map((item) => ExpenseCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>)
          .map((item) => ExpenseRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
