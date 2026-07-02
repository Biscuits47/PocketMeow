import 'dart:io';

import 'package:pocket_meow/app/state/pocket_meow_store.dart';
import 'package:pocket_meow/data/models/app_models.dart';

void main() async {
  final store = PocketMeowStore();
  await store.load();

  String infer(String note, String categoryStr, RecordType type) {
    String categoryId = type == RecordType.income ? 'transfer' : 'daily';
    
    if (categoryStr == '转账') {
      try {
        return store.categories.firstWhere((c) => c.name == '转账' && c.type == type).id;
      } catch (e) {}
    }
    
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
      } else if (categoryStr.contains('日用') ||
          categoryStr.contains('百货') ||
          categoryStr.contains('服饰') ||
          categoryStr.contains('数码电器')) {
        targetName = '购物';
      }

      if (targetName.isNotEmpty) {
        try {
          return store.categories.firstWhere((c) => c.name == targetName && c.type == type).id;
        } catch (e) {}
      } else {
        try {
          return store.categories.firstWhere((c) => c.name == categoryStr && c.type == type).id;
        } catch (e) {}
      }
    }
    return categoryId;
  }

  print('数码电器: ${infer('xx', '数码电器', RecordType.expense)}');
  print('其他: ${infer('xx', '其他', RecordType.expense)}');
  print('母婴亲子: ${infer('xx', '母婴亲子', RecordType.expense)}');
  
  print('Daily cat exists: ${store.categoryById('daily')?.name}');
  
  exit(0);
}
