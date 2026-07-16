import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/app_models.dart';

class AppStorage {
  static const databaseName = 'pocket_meow.db';
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await databasePath();
    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE app_meta(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE categories(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            colorValue INTEGER NOT NULL,
            iconKey TEXT NOT NULL,
            limitValue REAL NOT NULL,
            type TEXT NOT NULL,
            isSystem INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE records(
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            categoryId TEXT NOT NULL,
            note TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            type TEXT NOT NULL,
            excludeFromBudget INTEGER NOT NULL DEFAULT 0,
            source TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE budget_config(
            id INTEGER PRIMARY KEY,
            cycleStartDay INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE budget_buckets(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            colorValue INTEGER NOT NULL,
            limitValue REAL NOT NULL,
            sortOrder INTEGER NOT NULL,
            isSystem INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE budget_bucket_categories(
            bucketId TEXT NOT NULL,
            categoryId TEXT NOT NULL,
            PRIMARY KEY(bucketId, categoryId)
          )
        ''');
        await db.execute('''
          CREATE TABLE budget_plan_snapshots(
            periodStart TEXT PRIMARY KEY,
            planJson TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE UNIQUE INDEX budget_bucket_categories_category_unique ON budget_bucket_categories(categoryId)');
        await db.insert('budget_config', {'id': 1, 'cycleStartDay': 1});
        await db.insert(
          'budget_buckets',
          {
            'id': 'other',
            'name': '其它',
            'colorValue': 0xFFB0BEC5,
            'limitValue': 0.0,
            'sortOrder': 999,
            'isSystem': 1,
          },
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE records ADD COLUMN excludeFromBudget INTEGER NOT NULL DEFAULT 0');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS budget_config(
              id INTEGER PRIMARY KEY,
              cycleStartDay INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS budget_buckets(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              colorValue INTEGER NOT NULL,
              limitValue REAL NOT NULL,
              sortOrder INTEGER NOT NULL,
              isSystem INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS budget_bucket_categories(
              bucketId TEXT NOT NULL,
              categoryId TEXT NOT NULL,
              PRIMARY KEY(bucketId, categoryId)
            )
          ''');
          await db.execute(
              'CREATE UNIQUE INDEX IF NOT EXISTS budget_bucket_categories_category_unique ON budget_bucket_categories(categoryId)');

          final configRows = await db.query('budget_config', limit: 1);
          if (configRows.isEmpty) {
            await db.insert('budget_config', {'id': 1, 'cycleStartDay': 1});
          }

          final bucketRows = await db.query('budget_buckets', limit: 1);
          if (bucketRows.isEmpty) {
            double totalBudget = 0;
            final meta = await db.query(
              'app_meta',
              where: 'key = ?',
              whereArgs: ['totalBudget'],
              limit: 1,
            );
            if (meta.isNotEmpty) {
              totalBudget = double.tryParse(meta.first['value'] as String) ?? 0;
            }

            await db.insert(
              'budget_buckets',
              {
                'id': 'default',
                'name': '默认预算',
                'colorValue': 0xFF4DB6AC,
                'limitValue': totalBudget,
                'sortOrder': 0,
                'isSystem': 0,
              },
            );
            await db.insert(
              'budget_buckets',
              {
                'id': 'other',
                'name': '其它',
                'colorValue': 0xFFB0BEC5,
                'limitValue': 0.0,
                'sortOrder': 999,
                'isSystem': 1,
              },
            );

            final categoryRows = await db.query(
              'categories',
              columns: ['id', 'type'],
            );
            for (final row in categoryRows) {
              if ((row['type'] as String?) != 'expense') {
                continue;
              }
              await db.insert(
                'budget_bucket_categories',
                {
                  'bucketId': 'default',
                  'categoryId': row['id'] as String,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS budget_plan_snapshots(
              periodStart TEXT PRIMARY KEY,
              planJson TEXT NOT NULL
            )
          ''');

          final snapshotRows =
              await db.query('budget_plan_snapshots', limit: 1);
          if (snapshotRows.isEmpty) {
            final configRows = await db.query('budget_config', limit: 1);
            final cycleStartDay = (configRows.isEmpty
                    ? 1
                    : (configRows.first['cycleStartDay'] as int?)) ??
                1;
            final now = DateTime.now();
            final periodStart = now.day >= cycleStartDay
                ? DateTime(now.year, now.month, cycleStartDay)
                : DateTime(now.year, now.month - 1, cycleStartDay);
            final bucketRows = await db.query('budget_buckets');
            final linkRows = await db.query('budget_bucket_categories');
            final plan = BudgetPlan(
              periodStart: periodStart,
              buckets: bucketRows
                  .map(
                    (row) => BudgetBucket(
                      id: row['id'] as String,
                      name: row['name'] as String,
                      colorValue: row['colorValue'] as int,
                      limitValue: (row['limitValue'] as num).toDouble(),
                      sortOrder: (row['sortOrder'] as num?)?.toInt() ?? 0,
                      isSystem: (row['isSystem'] as int? ?? 0) == 1,
                    ),
                  )
                  .toList(),
              bucketCategories: linkRows
                  .map(
                    (row) => BudgetBucketCategoryLink(
                      bucketId: row['bucketId'] as String,
                      categoryId: row['categoryId'] as String,
                    ),
                  )
                  .toList(),
            );
            await db.insert(
              'budget_plan_snapshots',
              {
                'periodStart': periodStart.toIso8601String(),
                'planJson': jsonEncode(plan.toJson()),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE records ADD COLUMN source TEXT');
        }
      },
    );
    return _database!;
  }

  Future<String> databasePath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, databaseName);
  }

  Future<String> dataSafetySummary() async {
    if (kIsWeb) {
      return '当前数据保存在浏览器本地数据库中，刷新页面不会丢失，但清理浏览器站点数据后会被移除。';
    }

    final path = await databasePath();
    return '当前账单保存在设备本地 SQLite 数据库中，覆盖安装新版本 APK 时不会清空。仅在卸载应用、手动清除应用数据或点击“恢复初始状态”时才会被移除。\n\n数据库位置：$path';
  }

  Future<AppSnapshot?> loadSnapshot() async {
    final db = await database;
    final metaRows = await db.query('app_meta');
    if (metaRows.isEmpty) {
      return null;
    }

    double budget = 0;
    bool autoEnabled = false;

    for (final row in metaRows) {
      final key = row['key'] as String;
      final value = row['value'] as String;
      if (key == 'totalBudget') {
        budget = double.tryParse(value) ?? 0;
      } else if (key == 'isAutoBookkeepingEnabled') {
        autoEnabled = value == 'true';
      }
    }

    final categoryRows = await db.query('categories');
    final recordRows = await db.query('records');
    final configRows = await db.query('budget_config', limit: 1);
    final bucketRows = await db.query('budget_buckets');
    final bucketCategoryRows = await db.query('budget_bucket_categories');
    final budgetPlanRows = await db.query('budget_plan_snapshots');

    final cycleStartDay = (configRows.isEmpty
            ? 1
            : (configRows.first['cycleStartDay'] as int?)) ??
        1;

    return AppSnapshot(
      totalBudget: budget,
      isAutoBookkeepingEnabled: autoEnabled,
      categories: categoryRows
          .map(
            (row) => ExpenseCategory(
              id: row['id'] as String,
              name: row['name'] as String,
              colorValue: row['colorValue'] as int,
              iconKey: row['iconKey'] as String,
              limit: (row['limitValue'] as num).toDouble(),
              type: RecordTypeX.fromKey(row['type'] as String?),
              isSystem: (row['isSystem'] as int? ?? 1) == 1,
            ),
          )
          .toList(),
      expenses: recordRows
          .map(
            (row) => ExpenseRecord(
              id: row['id'] as String,
              amount: (row['amount'] as num).toDouble(),
              categoryId: row['categoryId'] as String,
              note: row['note'] as String? ?? '',
              createdAt: DateTime.parse(row['createdAt'] as String),
              type: RecordTypeX.fromKey(row['type'] as String?),
              excludeFromBudget: (row['excludeFromBudget'] as int? ?? 0) == 1,
              source: RecordSourceX.fromKey(row['source'] as String?),
            ),
          )
          .toList(),
      budgetCycleStartDay: cycleStartDay,
      budgetBuckets: bucketRows
          .map(
            (row) => BudgetBucket(
              id: row['id'] as String,
              name: row['name'] as String,
              colorValue: row['colorValue'] as int,
              limitValue: (row['limitValue'] as num).toDouble(),
              sortOrder: (row['sortOrder'] as num?)?.toInt() ?? 0,
              isSystem: (row['isSystem'] as int? ?? 0) == 1,
            ),
          )
          .toList(),
      budgetBucketCategories: bucketCategoryRows
          .map(
            (row) => BudgetBucketCategoryLink(
              bucketId: row['bucketId'] as String,
              categoryId: row['categoryId'] as String,
            ),
          )
          .toList(),
      budgetPlans: budgetPlanRows
          .map(
            (row) => BudgetPlan.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(row['planJson'] as String) as Map,
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('app_meta');
      await txn.delete('categories');
      await txn.delete('records');
      await txn.delete('budget_config');
      await txn.delete('budget_buckets');
      await txn.delete('budget_bucket_categories');
      await txn.delete('budget_plan_snapshots');

      await txn.insert(
        'app_meta',
        {
          'key': 'totalBudget',
          'value': snapshot.totalBudget.toString(),
        },
      );

      await txn.insert(
        'app_meta',
        {
          'key': 'isAutoBookkeepingEnabled',
          'value': snapshot.isAutoBookkeepingEnabled.toString(),
        },
      );

      for (final category in snapshot.categories) {
        await txn.insert(
          'categories',
          {
            'id': category.id,
            'name': category.name,
            'colorValue': category.colorValue,
            'iconKey': category.iconKey,
            'limitValue': category.limit,
            'type': category.type.key,
            'isSystem': category.isSystem ? 1 : 0,
          },
        );
      }

      for (final expense in snapshot.expenses) {
        await txn.insert(
          'records',
          {
            'id': expense.id,
            'amount': expense.amount,
            'categoryId': expense.categoryId,
            'note': expense.note,
            'createdAt': expense.createdAt.toIso8601String(),
            'type': expense.type.key,
            'excludeFromBudget': expense.excludeFromBudget ? 1 : 0,
            'source': expense.source?.key,
          },
        );
      }

      await txn.insert(
        'budget_config',
        {
          'id': 1,
          'cycleStartDay': snapshot.budgetCycleStartDay.clamp(1, 28),
        },
      );

      for (final bucket in snapshot.budgetBuckets) {
        await txn.insert(
          'budget_buckets',
          {
            'id': bucket.id,
            'name': bucket.name,
            'colorValue': bucket.colorValue,
            'limitValue': bucket.limitValue,
            'sortOrder': bucket.sortOrder,
            'isSystem': bucket.isSystem ? 1 : 0,
          },
        );
      }

      for (final link in snapshot.budgetBucketCategories) {
        await txn.insert(
          'budget_bucket_categories',
          {
            'bucketId': link.bucketId,
            'categoryId': link.categoryId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      for (final plan in snapshot.budgetPlans) {
        await txn.insert(
          'budget_plan_snapshots',
          {
            'periodStart': plan.periodStart.toIso8601String(),
            'planJson': jsonEncode(plan.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
