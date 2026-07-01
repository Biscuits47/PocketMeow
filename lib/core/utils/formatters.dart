import 'package:flutter/material.dart';

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
  return '${date.month} 月 ${date.day} 日';
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
