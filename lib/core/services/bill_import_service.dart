import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../data/models/app_models.dart';

class BillImportService {
  String _inferCategoryId(
      String note, String categoryStr, RecordType type, PocketMeowStore store) {
    String categoryId = type == RecordType.income ? 'salary' : 'daily';

    // 1. First try to map from Alipay's category column
    if (categoryStr.isNotEmpty) {
      String targetName = '';
      if (categoryStr.contains('餐饮美食')) {
        targetName = '餐饮';
      } else if (categoryStr.contains('医疗健康')) {
        targetName = '医疗';
      } else if (categoryStr.contains('交通出行')) {
        targetName = '交通';
      } else if (categoryStr.contains('文化休闲')) {
        targetName = '娱乐';
      } else if (categoryStr.contains('日用') ||
          categoryStr.contains('百货') ||
          categoryStr.contains('服饰')) {
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

    // 2. Smart inference based on note keywords
    if (note.isNotEmpty) {
      final text = note.toLowerCase();

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
        '哈啰'
      ];
      for (final kw in transportKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '交通' && c.type == type);
            return cat.id;
          } catch (e) {}
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
        '喜茶',
        '点单'
      ];
      for (final kw in foodKeywords) {
        if (text.contains(kw)) {
          try {
            final cat = store.categories
                .firstWhere((c) => c.name == '餐饮' && c.type == type);
            return cat.id;
          } catch (e) {}
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
          } catch (e) {}
        }
      }
    }

    return categoryId;
  }

  Future<int> importAlipayBill(PlatformFile file, PocketMeowStore store) async {
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

    int timeIdx = -1,
        itemIdx = -1,
        typeIdx = -1,
        amountIdx = -1,
        methodIdx = -1,
        categoryIdx = -1;
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
        }
        if (timeIdx != -1 && amountIdx != -1) {
          foundHeader = true;
        }
        continue;
      }

      if (foundHeader && row.length > timeIdx) {
        var timeStr = row[timeIdx]?.toString().trim() ?? '';
        if (timeStr.isEmpty) continue;

        DateTime? time;
        try {
          time = DateTime.parse(timeStr);
        } catch (e) {
          continue;
        }

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

        if (typeStr == '/' || typeStr == '不计收支') continue;

        RecordType type =
            typeStr.contains('收入') ? RecordType.income : RecordType.expense;

        amountStr = amountStr.replaceAll('¥', '').replaceAll(',', '').trim();
        double? amount = double.tryParse(amountStr);
        if (amount == null || amount <= 0) continue;

        String note = itemStr;
        if (methodStr.isNotEmpty && methodStr != '/') {
          note += ' ($methodStr)';
        }

        String categoryId = _inferCategoryId(note, categoryStr, type, store);

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
    return importedCount;
  }

  Future<int> importWeChatBill(PlatformFile file, PocketMeowStore store) async {
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

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      int timeIdx = -1,
          itemIdx = -1,
          typeIdx = -1,
          amountIdx = -1,
          methodIdx = -1,
          counterpartyIdx = -1;
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
          }
          if (timeIdx != -1 && amountIdx != -1) {
            foundHeader = true;
          }
          continue;
        }

        if (foundHeader && row.length > timeIdx) {
          var timeStr = row[timeIdx]?.value?.toString() ?? '';
          if (timeStr.isEmpty) continue;

          DateTime? time;
          try {
            time = DateTime.parse(timeStr);
          } catch (e) {
            continue;
          }

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

          if (typeStr == '/') continue; // e.g. transfers between own accounts

          RecordType type =
              typeStr.contains('收入') ? RecordType.income : RecordType.expense;

          amountStr = amountStr.replaceAll('¥', '').replaceAll(',', '').trim();
          double? amount = double.tryParse(amountStr);
          if (amount == null || amount <= 0) continue;

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

          if (methodStr.isNotEmpty && methodStr != '/') {
            note += ' ($methodStr)';
          }

          String categoryId = _inferCategoryId(note, '', type, store);

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
    return importedCount;
  }
}
