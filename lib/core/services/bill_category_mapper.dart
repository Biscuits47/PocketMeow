import '../../app/state/pocket_meow_store.dart';
import '../../data/models/app_models.dart';

class BillCategoryMapper {
  static String inferCategoryId(
    String note,
    String categoryStr,
    RecordType type,
    PocketMeowStore store,
  ) {
    String categoryId = type == RecordType.income ? 'transfer' : 'daily';

    if (categoryStr == '转账') {
      final id = _findCategoryId(store, '转账', type);
      if (id != null) return id;
    }

    if (note.isNotEmpty) {
      final text = note.toLowerCase();

      final rentId = _matchKeywords(store, type, text, const [
        '房租',
        '交租',
        '租金',
        '押金',
        '公寓',
        '合租',
      ], '房租');
      if (rentId != null) return rentId;

      final livingExpensesId = _matchKeywords(store, type, text, const [
        '水费',
        '电费',
        '热水',
        '话费',
        '水电',
      ], '生活缴费');
      if (livingExpensesId != null) return livingExpensesId;

      final transportId = _matchKeywords(store, type, text, const [
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
        '12306',
      ], '交通');
      if (transportId != null) return transportId;

      final foodId = _matchKeywords(store, type, text, const [
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
        'koi',
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
        '魔盒citybox',
        '左庭右院',
        '古茗',
        '可口可乐',
        '廣蓮申',
        '卤肉饭',
        '天好',
        'coffee',
        '点餐',
        '包子',
        '秦关中',
        '小吃',
        '水果',
        '盒马',
      ], '餐饮');
      if (foodId != null) return foodId;

      final shoppingId = _matchKeywords(store, type, text, const [
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
        '买菜',
      ], '购物');
      if (shoppingId != null) return shoppingId;

      final medicalId = _matchKeywords(store, type, text, const [
        '口腔',
        '医保',
        '住院',
        '门诊',
        '药房',
        '药店',
        '医院',
        '体检',
      ], '医疗');
      if (medicalId != null) return medicalId;

      final entertainmentId = _matchKeywords(store, type, text, const [
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
        'ktv',
        '密室',
        '剧本杀',
        'psn',
      ], '娱乐');
      if (entertainmentId != null) return entertainmentId;
    }

    if (categoryStr.isNotEmpty) {
      String targetName = '';
      if (categoryStr.contains('餐饮美食')) {
        targetName = '餐饮';
      } else if (categoryStr.contains('医疗健康')) {
        targetName = '医疗';
      } else if (categoryStr.contains('交通出行')) {
        targetName = '交通';
      } else if (categoryStr.contains('文化休闲') ||
          categoryStr.contains('酒店旅游')) {
        targetName = '娱乐';
      } else if (categoryStr.contains('退款')) {
        targetName = '退款';
      } else if (categoryStr.contains('转账') ||
          categoryStr.contains('红包') ||
          categoryStr.contains('群收款')) {
        targetName = '转账';
      } else if (categoryStr.contains('日用') || categoryStr.contains('百货')) {
        targetName = '日用';
      } else if (categoryStr.contains('服饰') ||
          categoryStr.contains('数码电器')) {
        targetName = '购物';
      }

      if (targetName.isNotEmpty) {
        final id = _findCategoryId(store, targetName, type);
        if (id != null) return id;
      } else {
        final id = _findCategoryId(store, categoryStr, type);
        if (id != null) return id;
      }
    }

    return categoryId;
  }

  static String? _matchKeywords(
    PocketMeowStore store,
    RecordType type,
    String text,
    List<String> keywords,
    String categoryName,
  ) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return _findCategoryId(store, categoryName, type);
      }
    }
    return null;
  }

  static String? _findCategoryId(
    PocketMeowStore store,
    String categoryName,
    RecordType type,
  ) {
    try {
      final category = store.categories
          .firstWhere((item) => item.name == categoryName && item.type == type);
      return category.id;
    } catch (_) {
      return null;
    }
  }
}
