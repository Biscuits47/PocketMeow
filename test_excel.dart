import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = r'F:\Files\Downloads\微信支付账单流水文件(20250701-20260701)_20260701164825.xlsx';
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);
  for (var table in excel.tables.keys) {
    print('Table: $table');
    var sheet = excel.tables[table]!;
    for (var i = 0; i < 25; i++) {
      if (i < sheet.rows.length) {
        var row = sheet.rows[i];
        print('Row $i: ${row.map((e) => e?.value?.toString()).toList()}');
      }
    }
  }
}
