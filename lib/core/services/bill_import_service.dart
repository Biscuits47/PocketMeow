import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../data/models/app_models.dart';

class BillImportService {
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
        methodIdx = -1;
    bool foundHeader = false;

    for (var row in rows) {
      if (!foundHeader) {
        for (int i = 0; i < row.length; i++) {
          var val = row[i]?.toString().trim() ?? '';
          if (val == '交易时间') timeIdx = i;
          if (val == '商品说明' || val == '商品') itemIdx = i;
          if (val == '收/支') typeIdx = i;
          if (val == '金额' || val == '金额（元）') amountIdx = i;
          if (val == '收/付款方式' || val == '支付方式') methodIdx = i;
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

        String categoryId = type == RecordType.income ? 'salary' : 'daily';

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
          methodIdx = -1;
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

          if (typeStr == '/') continue; // e.g. transfers between own accounts

          RecordType type =
              typeStr.contains('收入') ? RecordType.income : RecordType.expense;

          amountStr = amountStr.replaceAll('¥', '').replaceAll(',', '').trim();
          double? amount = double.tryParse(amountStr);
          if (amount == null || amount <= 0) continue;

          String note = itemStr;
          if (methodStr.isNotEmpty && methodStr != '/') {
            note += ' ($methodStr)';
          }

          // Use default category based on type
          String categoryId = type == RecordType.income ? 'salary' : 'daily';

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
