import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../data/models/app_models.dart';

class ImportResult {
  ImportResult({required this.importedCount, required this.invalidRecords});
  final int importedCount;
  final List<ExpenseRecord> invalidRecords;
}

class BillImportService {
  DateTime? _parseDateRobust(String timeStr) {
    try {
      return DateTime.parse(timeStr.replaceAll('/', '-'));
    } catch (e) {
      try {
        var parts = timeStr.trim().split(RegExp(r'\s+'));
        var dateParts = parts[0].replaceAll('/', '-').split('-');
        if (dateParts.length < 3) return null;
        int year = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int day = int.parse(dateParts[2]);

        int hour = 0, minute = 0, second = 0;
        if (parts.length > 1) {
          var timeParts = parts[1].split(':');
          if (timeParts.isNotEmpty) hour = int.parse(timeParts[0]);
          if (timeParts.length > 1) minute = int.parse(timeParts[1]);
          if (timeParts.length > 2) second = int.parse(timeParts[2]);
        }
        return DateTime(year, month, day, hour, minute, second);
      } catch (e) {
        return null;
      }
    }
  }

  String _inferCategoryId(
      String note, String categoryStr, RecordType type, PocketMeowStore store) {
    String categoryId = type == RecordType.income ? 'transfer' : 'daily';

    // 1. Check if categoryStr is explicitly '转账' from our hint
    if (categoryStr == '转账') {
      try {
        final cat = store.categories
            .firstWhere((c) => c.name == '转账' && c.type == type);
        return cat.id;
      } catch (e) {
        // Fall through
      }
    }

    // 2. Smart inference based on note keywords (Higher Priority)
    if (note.isNotEmpty) {
      final text = note.toLowerCase();

      // Keywords for Rent
      final rentKeywords = ['房租', '交租', '租金', '押金', '公寓', '合租'];
      for (final kw in rentKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '房租' && c.type == type);
            return cat.id;
          } catch (e) {
            // Ignore
          }
        }
      }

      // Keywords for Living Expenses (Utilities)
      final livingExpensesKeywords = ['水费', '电费', '热水', '话费', '水电'];
      for (final kw in livingExpensesKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '生活缴费' && c.type == type);
            return cat.id;
          } catch (e) {
            // Ignore
          }
        }
      }

      // Keywords for Transport
      final transportKeywords = [
        '地铁',
        '交通',
        '公交',
        '火车票',
        '飞机票',
        '高德',
        '打车',
        '滴滴',
        '轮渡',
        '大巴',
        '单车',
        '哈啰',
        '中铁网络',
        '铁路',
        '12306'
      ];
      for (final kw in transportKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '交通' && c.type == type);
            return cat.id;
          } catch (e) {
            // Ignore
          }
        }
      }

      // Keywords for Food/Restaurant
      final foodKeywords = [
        '美团',
        '饿了么',
        '外卖',
        '汉堡',
        '肯德基',
        '麦当劳',
        '塔斯汀',
        '大众点评',
        '萨莉亚',
        '餐饮',
        '乡村基',
        '食堂',
        '咖啡',
        '瑞幸',
        '库迪',
        '星巴克',
        '奶茶',
        '霸王茶姬',
        'KOI',
        '1点点',
        '堂食',
        '柠檬向右',
        '喜茶',
        'luckin coffee',
        '点单',
        '早餐',
        '午餐',
        '晚餐',
        '面条',
        '炒饭',
        '闪购',
        '一辛萬屋',
        '烧饼',
        '马记永',
        '魔盒CITYBOX',
        '左庭右院',
        '古茗',
        '可口可乐',
        '廣蓮申',
        '卤肉饭',
        '天好',
        'Coffee',
        '点餐',
        '包子',
        '秦关中',
        '小吃',
        '水果',
        '盒马',
      ];
      for (final kw in foodKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '餐饮' && c.type == type);
            return cat.id;
          } catch (e) {
            // Ignore
          }
        }
      }

      // Keywords for Shopping
      final shoppingKeywords = [
        '淘宝',
        '天猫',
        '京东',
        '拼多多',
        '超市',
        '便利店',
        '美宜佳',
        '全家',
        '7-11',
        '罗森',
        '买菜'
      ];
      for (final kw in shoppingKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '购物' && c.type == type);
            return cat.id;
          } catch (e) {
            // Ignore
          }
        }
      }
      // Keywords for Medical
      final medicalKeywords = ['口腔', '医保', '住院', '门诊', '药房', '药店', '医院', '体检'];
      for (final kw in medicalKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '医疗' && c.type == type);
            return cat.id;
          } catch (e) {
            // Ignore
          }
        }
      }
      // Keywords for Entertainment
      final entertainmentKeywords = [
        '旅游',
        '门票',
        '彩票',
        'steam',
        'epic',
        'ps5',
        'playstation',
        '游戏',
        '电影',
        '网吧',
        'KTV',
        '密室',
        '剧本杀'
            'psn'
      ];
      for (final kw in entertainmentKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '娱乐' && c.type == type);
            return cat.id;
          } catch (e) {
            // Ignore
          }
        }
      }
    }

    // 3. Fallback to map from Alipay's category column (Lower Priority)
    if (categoryStr.isNotEmpty) {
      String targetName = '';
      if (categoryStr.contains('餐饮美食')) {
        targetName = '餐饮';
      } else if (categoryStr.contains('医疗健康')) {
        targetName = '医疗';
      } else if (categoryStr.contains('交通出行')) {
        targetName = '交通';
      } else if (categoryStr.contains('文化休闲') || categoryStr.contains('酒店旅游')) {
        targetName = '娱乐';
      } else if (categoryStr.contains('退款')) {
        targetName = '退款';
      } else if (categoryStr.contains('转账') ||
          categoryStr.contains('红包') ||
          categoryStr.contains('群收款')) {
        targetName = '转账';
      } else if (categoryStr.contains('日用') || categoryStr.contains('百货')) {
        targetName = '日用';
      } else if (categoryStr.contains('服饰') || categoryStr.contains('数码电器')) {
        targetName = '购物';
      }

      if (targetName.isNotEmpty) {
        try {
          final cat = store.categories
              .firstWhere((c) => c.name == targetName && c.type == type);
          return cat.id;
        } catch (e) {
          // Ignore
        }
      } else {
        try {
          final cat = store.categories
              .firstWhere((c) => c.name == categoryStr && c.type == type);
          return cat.id;
        } catch (e) {
          // Ignore
        }
      }
    }

    return categoryId;
  }

  Future<ImportResult> importAlipayBill(
      PlatformFile file, PocketMeowStore store) async {
    List<int>? bytes;
    if (file.bytes != null) {
      bytes = file.bytes;
    } else if (file.path != null) {
      bytes = File(file.path!).readAsBytesSync();
    }
    if (bytes == null) throw Exception('无法读取文件');

    final csvString = gbk.decode(bytes);
    final rows = Csv().decode(csvString);
    int importedCount = 0;
    List<ExpenseRecord> invalidRecords = [];

    int timeIdx = -1,
        itemIdx = -1,
        typeIdx = -1,
        amountIdx = -1,
        methodIdx = -1,
        categoryIdx = -1,
        counterpartyIdx = -1,
        statusIdx = -1;
    bool foundHeader = false;

    for (var row in rows) {
      if (!foundHeader) {
        for (int i = 0; i < row.length; i++) {
          var val = row[i]?.toString().trim() ?? '';
          if (val == '交易时间') timeIdx = i;
          if (val == '商品说明' || val == '商品' || val == '商品名称') itemIdx = i;
          if (val == '收/支') typeIdx = i;
          if (val == '金额' || val == '金额（元）') amountIdx = i;
          if (val == '收/付款方式' || val == '支付方式') methodIdx = i;
          if (val == '交易分类') categoryIdx = i;
          if (val == '交易对方') counterpartyIdx = i;
          if (val == '交易状态') statusIdx = i;
        }
        if (timeIdx != -1 && amountIdx != -1) {
          foundHeader = true;
        }
        continue;
      }

      if (foundHeader && row.length > timeIdx) {
        var timeStr = row[timeIdx]?.toString().trim() ?? '';
        if (timeStr.isEmpty) continue;

        DateTime? time = _parseDateRobust(timeStr);
        if (time == null) continue;

        var itemStr =
            itemIdx != -1 ? (row[itemIdx]?.toString().trim() ?? '') : '';
        var typeStr =
            typeIdx != -1 ? (row[typeIdx]?.toString().trim() ?? '') : '';
        var amountStr =
            amountIdx != -1 ? (row[amountIdx]?.toString().trim() ?? '') : '';
        var methodStr =
            methodIdx != -1 ? (row[methodIdx]?.toString().trim() ?? '') : '';
        var categoryStr = categoryIdx != -1
            ? (row[categoryIdx]?.toString().trim() ?? '')
            : '';
        var counterpartyStr = counterpartyIdx != -1
            ? (row[counterpartyIdx]?.toString().trim() ?? '')
            : '';
        var statusStr =
            statusIdx != -1 ? (row[statusIdx]?.toString().trim() ?? '') : '';

        String note = itemStr;
        if (methodStr.isNotEmpty && methodStr != '/') {
          note += ' ($methodStr)';
        }

        bool isInvalid = false;
        RecordType type = RecordType.expense;

        if (statusStr == '交易关闭' || statusStr == '退款给指定账户') {
          isInvalid = true;
        } else if (itemStr == '支付宝小荷包-转出到银行卡' || itemStr == '支付宝小荷包-自动攒') {
          isInvalid = true;
        } else {
          if (typeStr.contains('收入')) {
            type = RecordType.income;
          } else if (typeStr.contains('支出')) {
            type = RecordType.expense;
          } else if (statusStr.contains('退款') ||
              itemStr.contains('退款') ||
              categoryStr.contains('退款')) {
            type = RecordType.income;
          } else if (itemStr.contains('收益发放') || itemStr.contains('收款')) {
            type = RecordType.income;
          } else if (typeStr == '不计收支' || typeStr == '/') {
            if (statusStr != '交易成功') {
              isInvalid = true;
            } else if (itemStr.contains('充值') ||
                itemStr.contains('转入') ||
                itemStr.contains('转出') ||
                itemStr.contains('提现') ||
                itemStr.contains('信用卡还款') ||
                itemStr.contains('收益发放') ||
                itemStr.contains('红包')) {
              isInvalid = true;
            } else if (!counterpartyStr.contains('小荷包') &&
                !counterpartyStr.contains('小金库') &&
                !itemStr.contains('小荷包') &&
                !itemStr.contains('小金库')) {
              isInvalid = true;
            } else {
              type = RecordType.expense;
            }
          } else {
            isInvalid = true;
          }
        }

        amountStr = amountStr.replaceAll('¥', '').replaceAll(',', '').trim();
        double? amount = double.tryParse(amountStr);
        if (amount == null ||
            amount <= 0 ||
            amount.isNaN ||
            amount.isInfinite) {
          isInvalid = true;
        }

        if (isInvalid) {
          final match = store.records
              .where((item) =>
                  item.note == note.trim() &&
                  item.createdAt.difference(time).inSeconds.abs() < 1)
              .firstOrNull;
          if (match != null && !invalidRecords.any((r) => r.id == match.id)) {
            invalidRecords.add(match);
          }
          continue;
        }

        if (amount == null) continue;

        String categoryId = '';
        final existingRecords =
            store.records.where((r) => r.note == note).toList();
        if (existingRecords.isNotEmpty) {
          existingRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          categoryId = existingRecords.first.categoryId;
        } else {
          categoryId = _inferCategoryId(note, categoryStr, type, store);
        }

        int previousCount = store.records.length;
        store.addRecord(
          amount: amount,
          categoryId: categoryId,
          note: note,
          type: type,
          createdAt: time,
        );
        if (store.records.length > previousCount) {
          importedCount++;
        }
      }
    }
    return ImportResult(
      importedCount: importedCount,
      invalidRecords: invalidRecords,
    );
  }

  Future<ImportResult> importWeChatBill(
      PlatformFile file, PocketMeowStore store) async {
    // Read bytes
    List<int>? bytes;
    if (file.bytes != null) {
      bytes = file.bytes;
    } else if (file.path != null) {
      bytes = File(file.path!).readAsBytesSync();
    }
    if (bytes == null) throw Exception('无法读取文件');

    var excel = Excel.decodeBytes(bytes);
    int importedCount = 0;
    List<ExpenseRecord> invalidRecords = [];

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      int timeIdx = -1,
          itemIdx = -1,
          typeIdx = -1,
          amountIdx = -1,
          methodIdx = -1,
          counterpartyIdx = -1,
          transactionTypeIdx = -1;
      bool foundHeader = false;

      for (var row in sheet.rows) {
        if (!foundHeader) {
          for (int i = 0; i < row.length; i++) {
            var val = row[i]?.value?.toString().trim() ?? '';
            if (val == '交易时间') timeIdx = i;
            if (val == '商品') itemIdx = i;
            if (val == '收/支') typeIdx = i;
            if (val.contains('金额')) amountIdx = i;
            if (val == '支付方式') methodIdx = i;
            if (val == '交易对方') counterpartyIdx = i;
            if (val == '交易类型') transactionTypeIdx = i;
          }
          if (timeIdx != -1 && amountIdx != -1) {
            foundHeader = true;
          }
          continue;
        }

        if (foundHeader && row.length > timeIdx) {
          var timeStr = row[timeIdx]?.value?.toString() ?? '';
          if (timeStr.isEmpty) continue;

          DateTime? time = _parseDateRobust(timeStr);
          if (time == null) continue;

          var itemStr =
              itemIdx != -1 ? (row[itemIdx]?.value?.toString() ?? '') : '';
          var typeStr =
              typeIdx != -1 ? (row[typeIdx]?.value?.toString() ?? '') : '';
          var amountStr =
              amountIdx != -1 ? (row[amountIdx]?.value?.toString() ?? '') : '';
          var methodStr =
              methodIdx != -1 ? (row[methodIdx]?.value?.toString() ?? '') : '';
          var counterpartyStr = counterpartyIdx != -1
              ? (row[counterpartyIdx]?.value?.toString() ?? '')
              : '';
          var transactionTypeStr = transactionTypeIdx != -1
              ? (row[transactionTypeIdx]?.value?.toString() ?? '')
              : '';

          bool isInvalid = false;
          if (typeStr == '/')
            isInvalid = true; // e.g. transfers between own accounts

          if (transactionTypeStr.contains('转入零钱通') ||
              transactionTypeStr.contains('零钱通转出')) {
            isInvalid = true;
          }

          amountStr = amountStr.replaceAll('¥', '').replaceAll(',', '').trim();
          double? amount = double.tryParse(amountStr);
          if (amount == null ||
              amount <= 0 ||
              amount.isNaN ||
              amount.isInfinite) {
            isInvalid = true;
          }

          String note = '';
          if (counterpartyStr.isNotEmpty &&
              itemStr.isNotEmpty &&
              itemStr != '/') {
            note = '$counterpartyStr-$itemStr';
          } else if (counterpartyStr.isNotEmpty && counterpartyStr != '/') {
            note = counterpartyStr;
          } else {
            note = itemStr;
          }

          if (note.startsWith('-')) note = note.substring(1);
          if (note.endsWith('-')) note = note.substring(0, note.length - 1);

          if (transactionTypeStr.contains('微信红包-退款')) {
            note = '微信红包-退款';
          }

          if (methodStr.isNotEmpty && methodStr != '/') {
            note += ' ($methodStr)';
          }

          if (isInvalid) {
            final match = store.records
                .where((item) =>
                    item.note == note.trim() &&
                    item.createdAt.difference(time).inSeconds.abs() < 1)
                .firstOrNull;
            if (match != null && !invalidRecords.any((r) => r.id == match.id)) {
              invalidRecords.add(match);
            }
            continue;
          }

          if (amount == null) continue;

          RecordType type =
              typeStr.contains('收入') ? RecordType.income : RecordType.expense;

          // Use transactionTypeStr as the category hint if it matches our transfer types
          String categoryHint = '';
          if (transactionTypeStr.contains('退款')) {
            categoryHint = '退款';
          } else if (transactionTypeStr.contains('转账') ||
              transactionTypeStr.contains('微信红包') ||
              transactionTypeStr.contains('群收款')) {
            categoryHint = '转账';
          }

          String categoryId = '';
          final existingRecords =
              store.records.where((r) => r.note == note).toList();
          if (existingRecords.isNotEmpty) {
            existingRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            categoryId = existingRecords.first.categoryId;
          } else {
            categoryId = _inferCategoryId(note, categoryHint, type, store);
          }
          int previousCount = store.records.length;
          store.addRecord(
            amount: amount,
            categoryId: categoryId,
            note: note,
            type: type,
            createdAt: time,
          );
          if (store.records.length > previousCount) {
            importedCount++;
          }
        }
      }
    }
    return ImportResult(
      importedCount: importedCount,
      invalidRecords: invalidRecords,
    );
  }
}
