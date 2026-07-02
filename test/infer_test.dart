import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_meow/app/state/pocket_meow_store.dart';
import 'package:pocket_meow/data/models/app_models.dart';
import 'package:pocket_meow/core/services/bill_import_service.dart';

void main() {
  test('Test infer category', () async {
    final store = PocketMeowStore();
    await store.load();
    final service = BillImportService();
    
    // Simulate what happens for '其他'
    final id1 = service.inferCategoryIdForTest('某个商品', '其他', RecordType.expense, store);
    print('Id for 其他: $id1');
    
    final id2 = service.inferCategoryIdForTest('某个商品', '母婴亲子', RecordType.expense, store);
    print('Id for 母婴亲子: $id2');
    
    final cat1 = store.categoryById(id1);
    print('Cat1: ${cat1?.name}');
  });
}
