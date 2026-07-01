import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../data/models/app_models.dart';

class BillImportService {
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
      int timeIdx = -1, itemIdx = -1, typeIdx = -1, amountIdx = -1, methodIdx = -1;
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

          var itemStr = itemIdx != -1 ? (row[itemIdx]?.value?.toString() ?? '') : '';
          var typeStr = typeIdx != -1 ? (row[typeIdx]?.value?.toString() ?? '') : '';
          var amountStr = amountIdx != -1 ? (row[amountIdx]?.value?.toString() ?? '') : '';
          var methodStr = methodIdx != -1 ? (row[methodIdx]?.value?.toString() ?? '') : '';

          if (typeStr == '/') continue; // e.g. transfers between own accounts

          RecordType type = typeStr.contains('收入') ? RecordType.income : RecordType.expense;

          amountStr = amountStr.replaceAll('¥', '').replaceAll(',', '').trim();
          double? amount = double.tryParse(amountStr);
          if (amount == null || amount <= 0) continue;

          String note = itemStr;
          if (methodStr.isNotEmpty && methodStr != '/') {
            note += ' ($methodStr)';
          }

          // Use default category based on type
          String categoryId = type == RecordType.income ? 'salary' : 'daily';

          store.addRecord(
            amount: amount,
            categoryId: categoryId,
            note: note,
            type: type,
            createdAt: time,
          );
          importedCount++;
        }
      }
    }
    return importedCount;
  }
}
