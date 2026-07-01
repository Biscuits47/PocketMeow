import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/app_models.dart';

class AppStorage {
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

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'pocket_meow.db');
    _database = await openDatabase(
      path,
      version: 1,
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
            type TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<AppSnapshot?> loadSnapshot() async {
    final db = await database;
    final metaRows = await db.query('app_meta', where: 'key = ?', whereArgs: ['totalBudget']);
    if (metaRows.isEmpty) {
      return null;
    }

    final budget = double.tryParse(metaRows.first['value'] as String? ?? '') ?? 0;
    final categoryRows = await db.query('categories');
    final recordRows = await db.query('records');

    return AppSnapshot(
      totalBudget: budget,
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

      await txn.insert(
        'app_meta',
        {
          'key': 'totalBudget',
          'value': snapshot.totalBudget.toString(),
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
          },
        );
      }
    });
  }
}
