import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../data/models/app_models.dart';

class CategoryIconOption {
  const CategoryIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const List<CategoryIconOption> kCategoryIconOptions = [
  CategoryIconOption(
    key: 'wallet',
    label: '钱包',
    icon: Icons.wallet_outlined,
  ),
  CategoryIconOption(
    key: 'salary',
    label: '工资',
    icon: Icons.account_balance_wallet_rounded,
  ),
  CategoryIconOption(
    key: 'gift',
    label: '礼物',
    icon: Icons.card_giftcard_rounded,
  ),
  CategoryIconOption(
    key: 'restaurant',
    label: '餐饮',
    icon: Icons.restaurant_rounded,
  ),
  CategoryIconOption(
    key: 'coffee',
    label: '咖啡',
    icon: Icons.local_cafe_outlined,
  ),
  CategoryIconOption(
    key: 'train',
    label: '交通',
    icon: Icons.train_rounded,
  ),
  CategoryIconOption(
    key: 'travel',
    label: '出行',
    icon: Icons.flight_takeoff_rounded,
  ),
  CategoryIconOption(
    key: 'shopping',
    label: '购物袋',
    icon: Icons.shopping_bag_rounded,
  ),
  CategoryIconOption(
    key: 'cart',
    label: '购物车',
    icon: Icons.shopping_cart_checkout_rounded,
  ),
  CategoryIconOption(
    key: 'movie',
    label: '娱乐',
    icon: Icons.movie_creation_outlined,
  ),
  CategoryIconOption(
    key: 'medical',
    label: '医疗',
    icon: Icons.local_hospital_outlined,
  ),
  CategoryIconOption(
    key: 'home',
    label: '居家',
    icon: Icons.home_work_outlined,
  ),
  CategoryIconOption(
    key: 'pets',
    label: '宠物',
    icon: Icons.pets_outlined,
  ),
  CategoryIconOption(
    key: 'book',
    label: '书籍',
    icon: Icons.menu_book_outlined,
  ),
  CategoryIconOption(
    key: 'fitness',
    label: '运动',
    icon: Icons.fitness_center_outlined,
  ),
  CategoryIconOption(
    key: 'music',
    label: '音乐',
    icon: Icons.music_note_outlined,
  ),
  CategoryIconOption(
    key: 'games',
    label: '游戏',
    icon: Icons.sports_esports_outlined,
  ),
  CategoryIconOption(
    key: 'child',
    label: '孩子',
    icon: Icons.child_care_outlined,
  ),
  CategoryIconOption(
    key: 'car',
    label: '汽车',
    icon: Icons.directions_car_outlined,
  ),
  CategoryIconOption(
    key: 'beauty',
    label: '丽人',
    icon: Icons.face_retouching_natural_outlined,
  ),
  CategoryIconOption(
    key: 'electronics',
    label: '数码',
    icon: Icons.computer_outlined,
  ),
  CategoryIconOption(
    key: 'education',
    label: '教育',
    icon: Icons.school_outlined,
  ),
  CategoryIconOption(
    key: 'bill',
    label: '账单',
    icon: Icons.receipt_long_outlined,
  ),
  CategoryIconOption(
    key: 'investment',
    label: '理财',
    icon: Icons.trending_up_outlined,
  ),
  CategoryIconOption(
    key: 'communication',
    label: '通讯',
    icon: Icons.phone_android_outlined,
  ),
  CategoryIconOption(
    key: 'social',
    label: '社交',
    icon: Icons.people_outline_rounded,
  ),
  // 新增图标 (Added icons)
  CategoryIconOption(
    key: 'water_drop',
    label: '水费',
    icon: Icons.water_drop_outlined,
  ),
  CategoryIconOption(
    key: 'electric_bolt',
    label: '电费',
    icon: Icons.electric_bolt_outlined,
  ),
  CategoryIconOption(
    key: 'gas',
    label: '燃气',
    icon: Icons.local_fire_department_outlined,
  ),
  CategoryIconOption(
    key: 'wifi',
    label: '宽带',
    icon: Icons.wifi_outlined,
  ),
  CategoryIconOption(
    key: 'cell_tower',
    label: '通信',
    icon: Icons.cell_tower_outlined,
  ),
  CategoryIconOption(
    key: 'monitor',
    label: '电视',
    icon: Icons.monitor_outlined,
  ),
  CategoryIconOption(
    key: 'delivery',
    label: '快递',
    icon: Icons.local_shipping_outlined,
  ),
  CategoryIconOption(
    key: 'cake',
    label: '蛋糕',
    icon: Icons.cake_outlined,
  ),
  CategoryIconOption(
    key: 'local_bar',
    label: '酒水',
    icon: Icons.local_bar_outlined,
  ),
  CategoryIconOption(
    key: 'fastfood',
    label: '快餐',
    icon: Icons.fastfood_outlined,
  ),
  CategoryIconOption(
    key: 'store',
    label: '商店',
    icon: Icons.storefront_outlined,
  ),
  CategoryIconOption(
    key: 'hotel',
    label: '酒店',
    icon: Icons.hotel_outlined,
  ),
  CategoryIconOption(
    key: 'directions_bus',
    label: '巴士',
    icon: Icons.directions_bus_outlined,
  ),
  CategoryIconOption(
    key: 'subway',
    label: '地铁',
    icon: Icons.subway_outlined,
  ),
  CategoryIconOption(
    key: 'local_taxi',
    label: '出租车',
    icon: Icons.local_taxi_outlined,
  ),
  CategoryIconOption(
    key: 'directions_bike',
    label: '单车',
    icon: Icons.directions_bike_outlined,
  ),
  CategoryIconOption(
    key: 'pedal_bike',
    label: '自行车',
    icon: Icons.pedal_bike_outlined,
  ),
  CategoryIconOption(
    key: 'savings',
    label: '储蓄',
    icon: Icons.savings_outlined,
  ),
  CategoryIconOption(
    key: 'currency_exchange',
    label: '兑换',
    icon: Icons.currency_exchange_outlined,
  ),
  CategoryIconOption(
    key: 'credit_card',
    label: '信用卡',
    icon: Icons.credit_card_outlined,
  ),
  CategoryIconOption(
    key: 'account_balance',
    label: '银行',
    icon: Icons.account_balance_outlined,
  ),
  CategoryIconOption(
    key: 'monetization_on',
    label: '金钱',
    icon: Icons.monetization_on_outlined,
  ),
  CategoryIconOption(
    key: 'stroller',
    label: '婴儿车',
    icon: Icons.stroller_outlined,
  ),
  CategoryIconOption(
    key: 'spa',
    label: '水疗',
    icon: Icons.spa_outlined,
  ),
  CategoryIconOption(
    key: 'brush',
    label: '美妆',
    icon: Icons.brush_outlined,
  ),
  CategoryIconOption(
    key: 'chair',
    label: '家具',
    icon: Icons.chair_outlined,
  ),
  CategoryIconOption(
    key: 'camera',
    label: '相机',
    icon: Icons.camera_alt_outlined,
  ),
  CategoryIconOption(
    key: 'smartphone',
    label: '手机',
    icon: Icons.smartphone_outlined,
  ),
  CategoryIconOption(
    key: 'watch',
    label: '手表',
    icon: Icons.watch_outlined,
  ),
];

String formatCurrency(double value) {
  return '¥${value.toStringAsFixed(2)}';
}

String formatShortCurrency(double value) {
  final sign = value < 0 ? '-' : '';
  final absValue = value.abs();
  if (absValue == absValue.roundToDouble()) {
    return '$sign¥${absValue.toInt()}';
  }
  return '$sign¥${absValue.toStringAsFixed(2)}';
}

String formatChartAmount(double value) {
  final sign = value < 0 ? '-' : '';
  final absValue = value.abs();

  if (absValue >= 10000) {
    final v = absValue / 10000;
    // Format to remove trailing zeros, but allow up to 2 decimal places if needed
    final str = v
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return '$sign¥$str万';
  }

  // Format with commas for thousands and handle floating point precision
  String str = absValue.toStringAsFixed(3);
  str = str.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');

  final parts = str.split('.');
  final String formattedInt = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

  if (parts.length > 1) {
    return '$sign¥$formattedInt.${parts[1]}';
  }
  return '$sign¥$formattedInt';
}

String formatChartTooltipAmount(double amount, {bool noDecimal = false}) {
  if (amount >= 10000) {
    final value = amount / 10000;
    if (noDecimal) {
      return '${value.toInt()}万';
    }
    // Show up to 2 decimal places for '万' and remove trailing zeros
    final str = value.toStringAsFixed(2);
    if (str.endsWith('.00')) {
      return '${str.substring(0, str.length - 3)}万';
    } else if (str.endsWith('0')) {
      return '${str.substring(0, str.length - 1)}万';
    }
    return '$str万';
  } else if (amount >= 1000) {
    if (noDecimal) {
      return NumberFormat('#,##0').format(amount);
    }
    // Add comma for thousands
    return NumberFormat('#,##0.##').format(amount);
  } else {
    if (noDecimal) {
      return amount.toInt().toString();
    }
    // Dynamic decimal points up to 2
    final str = amount.toStringAsFixed(2);
    if (str.endsWith('.00')) {
      return str.substring(0, str.length - 3);
    } else if (str.endsWith('0')) {
      return str.substring(0, str.length - 1);
    }
    return str;
  }
}

String formatPeriodLabel(DateTime date, ReportType type) {
  if (type == ReportType.yearly) {
    return '${date.year} 年';
  } else if (type == ReportType.monthly) {
    return '${date.year} 年 ${date.month} 月';
  } else {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    if (startOfWeek.month == endOfWeek.month) {
      return '${startOfWeek.year} 年 ${startOfWeek.month} 月 ${startOfWeek.day} 日 - ${endOfWeek.day} 日';
    }
    return '${startOfWeek.year} 年 ${startOfWeek.month} 月 ${startOfWeek.day} 日 - ${endOfWeek.month} 月 ${endOfWeek.day} 日';
  }
}

String formatShortPeriodLabel(DateTime date, ReportType type) {
  if (type == ReportType.yearly) {
    return '${date.year} 年';
  } else if (type == ReportType.monthly) {
    return '${date.year} 年 ${date.month} 月';
  } else {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return '${startOfWeek.year} 年 ${startOfWeek.month} 月 第 ${((date.day - 1) ~/ 7) + 1} 周';
  }
}

String formatMonthLabel(DateTime date) {
  return '${date.year} 年 ${date.month} 月';
}

String formatShortMonthLabel(DateTime date) {
  return '${date.month} 月';
}

String formatDayTime(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');

  if (diff == 0) {
    return '今天 $hh:$mm';
  }
  if (diff == 1) {
    return '昨天 $hh:$mm';
  }
  return '${date.month}/${date.day} $hh:$mm';
}

String formatDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) {
    return '今天';
  }
  if (diff == 1) {
    return '昨天';
  }
  if (date.year != now.year) {
    return '${date.year} 年 ${date.month} 月 ${date.day} 日';
  }
  return '${date.month} 月 ${date.day} 日';
}

String formatDayLabelWithWeekday(DateTime date) {
  final label = formatDayLabel(date);
  if (label == '今天' || label == '昨天') {
    return label;
  }
  return '$label · 星期${weekdayLabel(date.weekday)}';
}

String weekdayLabel(int weekday) {
  const values = ['一', '二', '三', '四', '五', '六', '日'];
  return values[(weekday - 1).clamp(0, 6)];
}

IconData iconForCategory(String iconKey) {
  return categoryIconOptionForKey(iconKey).icon;
}

CategoryIconOption categoryIconOptionForKey(String iconKey) {
  for (final option in kCategoryIconOptions) {
    if (option.key == iconKey) {
      return option;
    }
  }
  return kCategoryIconOptions.first;
}

String formatSignedAmount(double amount, RecordType type) {
  final sign = type == RecordType.income ? '+' : '-';
  return '$sign${formatCurrency(amount)}';
}
