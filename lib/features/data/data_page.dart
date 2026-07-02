import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';
import '../add_expense/add_expense_sheet.dart';
import '../records/records_page.dart';
import '../settings/settings_page.dart';

class DataPage extends StatelessWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('数据', style: theme.textTheme.headlineMedium),
                    ),
                    _SettingsShortcut(onTap: () => openSettingsPage(context)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ReportType>(
                    segments: const [
                      ButtonSegment(
                          value: ReportType.weekly, label: Text('周报')),
                      ButtonSegment(
                          value: ReportType.monthly, label: Text('月报')),
                      ButtonSegment(
                          value: ReportType.yearly, label: Text('年报')),
                    ],
                    selected: {store.reportType},
                    onSelectionChanged: (set) {
                      store.setReportType(set.first);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('图表分析', style: theme.textTheme.titleLarge),
                    _PeriodSwitchCompact(store: store),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [
                _SpendingDistributionCard(store: store),
                const SizedBox(height: 16),
                _TrendCard(store: store),
                const SizedBox(height: 16),
                _MonthlyHistoryCard(store: store),
                const SizedBox(height: 16),
                _InsightsSummaryCard(store: store),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsShortcut extends StatelessWidget {
  const _SettingsShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EBEE)),
        ),
        child: const Icon(Icons.settings_outlined),
      ),
    );
  }
}

class _SpendingDistributionCard extends StatelessWidget {
  const _SpendingDistributionCard({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = store.categorySpendData.toList();
    final total = store.monthSpent;
    final periodName = store.reportType == ReportType.yearly
        ? '年'
        : (store.reportType == ReportType.weekly ? '周' : '月');

    List<CategorySpendData> pieItems = [];
    final maxPieItems = 5;

    if (items.length > maxPieItems) {
      pieItems = items.take(maxPieItems).toList();
      final otherAmount =
          items.skip(maxPieItems).fold(0.0, (sum, item) => sum + item.amount);
      if (otherAmount > 0) {
        pieItems.add(CategorySpendData(
          category: const ExpenseCategory(
            id: 'other',
            name: '其他',
            iconKey: 'other',
            colorValue: 0xFF8E8CD8,
            limit: 0,
            type: RecordType.expense,
            isSystem: true,
          ),
          amount: otherAmount,
          count:
              items.skip(maxPieItems).fold(0, (sum, item) => sum + item.count),
        ));
      }
    } else {
      pieItems.addAll(items);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当$periodName支出分布', style: theme.textTheme.titleLarge),
            const SizedBox(height: 18),
            if (items.isEmpty)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FA),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  '还没有足够数据生成分析图表。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            centerSpaceRadius: 50,
                            sectionsSpace: 2,
                            sections: pieItems.map(
                              (item) {
                                return PieChartSectionData(
                                  color: Color(item.category.colorValue),
                                  value: item.amount,
                                  radius: 46,
                                  title: '',
                                );
                              },
                            ).toList(),
                          ),
                        ),
                        _PieChartLabelOverlay(
                          items: pieItems,
                          total: total,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              _showCategoryRecords(context, item.category),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.muted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Color(item.category.colorValue)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    iconForCategory(item.category.iconKey),
                                    size: 18,
                                    color: Color(item.category.colorValue),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(item.category.name,
                                              style:
                                                  theme.textTheme.titleMedium),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${item.count}笔',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: AppTheme.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: item.shareOf(total),
                                          minHeight: 4,
                                          backgroundColor:
                                              const Color(0xFFF1F4F6),
                                          valueColor: AlwaysStoppedAnimation<
                                                  Color>(
                                              Color(item.category.colorValue)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(item.shareOf(total) * 100).toStringAsFixed(2)}%',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatChartAmount(item.amount),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = store.periodTrendData;
    final maxAmount = data.fold<double>(
      0,
      (maxValue, item) => max(maxValue, max(item.expense, item.income)),
    );

    final title = store.reportType == ReportType.yearly
        ? '年度消费趋势'
        : (store.reportType == ReportType.monthly ? '月度消费趋势' : '本周消费趋势');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxAmount == 0 ? 100 : maxAmount * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxAmount == 0 ? 25 : maxAmount / 4,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFE8EDF0),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          // Only show partial labels if too many (like monthly view)
                          if (store.reportType == ReportType.monthly) {
                            if (index % 5 != 0 && index != data.length - 1) {
                              return const SizedBox.shrink();
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index].label,
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final label = data[spot.x.toInt()].label;
                          final amount = formatChartTooltipAmount(spot.y);
                          final prefix = spot.barIndex == 0 ? '支出: ' : '收入: ';
                          if (spot == touchedSpots.first) {
                            return LineTooltipItem(
                              '$label\n$prefix$amount',
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            );
                          } else {
                            return LineTooltipItem(
                              '$prefix$amount',
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            );
                          }
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: false,
                      preventCurveOverShooting: true,
                      color: AppTheme.warning,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.warning.withValues(alpha: 0.12),
                      ),
                      spots: List.generate(
                        data.length,
                        (index) =>
                            FlSpot(index.toDouble(), data[index].expense),
                      ),
                    ),
                    LineChartBarData(
                      isCurved: false,
                      preventCurveOverShooting: true,
                      color: AppTheme.mintDeep,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.mint.withValues(alpha: 0.12),
                      ),
                      spots: List.generate(
                        data.length,
                        (index) => FlSpot(index.toDouble(), data[index].income),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                _LegendDot(color: AppTheme.warning, label: '支出'),
                SizedBox(width: 16),
                _LegendDot(color: AppTheme.mintDeep, label: '收入'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsSummaryCard extends StatelessWidget {
  const _InsightsSummaryCard({required this.store});

  final PocketMeowStore store;

  String _formatComparison(double current, double previous, String label) {
    if (previous == 0 && current == 0) return '$label没有变化';
    if (previous == 0) return '$label增加 ${formatShortCurrency(current)}';

    final diff = current - previous;
    if (diff == 0) return '$label与上期持平';

    final action = diff > 0 ? '增加' : '减少';
    return '$label$action ${formatShortCurrency(diff.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topCategory =
        store.categorySpendData.isEmpty ? null : store.categorySpendData.first;

    final periodName = store.reportType == ReportType.yearly
        ? '年'
        : (store.reportType == ReportType.weekly ? '周' : '月');

    final currentExp = store.monthSpent;
    final currentInc = store.monthIncome;
    final currentBalance = store.totalBudget - currentExp;

    final prevExp = store.previousPeriodExpense;
    final prevInc = store.previousPeriodIncome;

    final balanceText = currentBalance >= 0
        ? '结余 ${formatShortCurrency(currentBalance)}'
        : '超支 ${formatShortCurrency(currentBalance.abs())}';

    final insights = [
      if (topCategory != null)
        '${topCategory.category.name} 是本$periodName最大支出，占比 ${(topCategory.shareOf(store.monthSpent) * 100).round()}%',
      '与上$periodName相比，${_formatComparison(currentExp, prevExp, '支出')}，${_formatComparison(currentInc, prevInc, '收入')}。',
      '本$periodName$balanceText，支出占收入的 ${currentInc > 0 ? ((currentExp / currentInc) * 100).round() : 0}%。'
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('智能总结', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            ...insights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.mintDeep,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyHistoryCard extends StatelessWidget {
  const _MonthlyHistoryCard({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = store.historyBarData;
    final maxAmount = data.fold<double>(
      0,
      (maxValue, item) => max(maxValue, max(item.expense, item.income)),
    );

    final title = store.reportType == ReportType.yearly
        ? '每月消费'
        : (store.reportType == ReportType.monthly ? '每周消费' : '每日消费');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxAmount == 0 ? 100 : maxAmount * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxAmount == 0 ? 25 : maxAmount / 4,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFE8EDF0),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = data[group.x.toInt()].label;
                        final amount = formatChartTooltipAmount(rod.toY);
                        final prefix = rodIndex == 0 ? '支出: ' : '收入: ';
                        return BarTooltipItem(
                          '$label\n$prefix$amount',
                          const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          // Only show partial labels if too many (like yearly view)
                          if (store.reportType == ReportType.yearly) {
                            if (index % 2 != 0 && index != data.length - 1) {
                              return const SizedBox.shrink();
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index].label,
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(data.length, (index) {
                    final item = data[index];
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 6,
                      barRods: [
                        BarChartRodData(
                          toY: item.expense,
                          width: 10,
                          borderRadius: BorderRadius.circular(999),
                          color: AppTheme.warning,
                        ),
                        BarChartRodData(
                          toY: item.income,
                          width: 10,
                          borderRadius: BorderRadius.circular(999),
                          color: AppTheme.mintDeep,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                _LegendDot(color: AppTheme.warning, label: '支出'),
                SizedBox(width: 16),
                _LegendDot(color: AppTheme.mintDeep, label: '收入'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PeriodSwitchCompact extends StatelessWidget {
  const _PeriodSwitchCompact({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBEE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: store.goToPreviousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
            visualDensity: VisualDensity.compact,
          ),
          Text(formatShortPeriodLabel(store.selectedDate, store.reportType)),
          IconButton(
            onPressed: store.canGoToNextMonth ? store.goToNextMonth : null,
            icon: const Icon(Icons.chevron_right_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

void _showCategoryRecords(BuildContext context, ExpenseCategory category) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return _CategoryRecordsSheet(
          category: category,
          scrollController: scrollController,
        );
      },
    ),
  );
}

class _CategoryRecordsSheet extends StatelessWidget {
  const _CategoryRecordsSheet({
    required this.category,
    required this.scrollController,
  });

  final ExpenseCategory category;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);

    final records = store.currentMonthRecords
        .where((r) => r.categoryId == category.id)
        .toList();

    final grouped = groupByDay(records, store);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(category.colorValue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconForCategory(category.iconKey),
                  size: 18,
                  color: Color(category.colorValue),
                ),
              ),
              const SizedBox(width: 12),
              Text('${category.name} 交易记录', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            const Expanded(
              child: Center(child: Text('没有交易记录')),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final section = grouped[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          formatDayLabel(section.date),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: AppTheme.muted),
                        ),
                      ),
                      ...section.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RecordRow(
                              item: item,
                              onTap: () {
                                Navigator.pop(context);
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) =>
                                      AddExpenseSheet(expense: item.record),
                                );
                              },
                            ),
                          )),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PieChartLabelOverlay extends StatelessWidget {
  const _PieChartLabelOverlay({
    required this.items,
    required this.total,
  });

  final List<CategorySpendData> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PieChartLabelPainter(
        items: items,
        total: total,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PieChartLabelPainter extends CustomPainter {
  _PieChartLabelPainter({
    required this.items,
    required this.total,
  });

  final List<CategorySpendData> items;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty || total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    const pieOuterRadius = 96.0; // centerSpaceRadius(50) + radius(46)
    const line1Length = 14.0;
    const line2Length = 16.0;

    double currentAngle = -90.0;

    // Adjust these to handle label collisions
    List<Rect> labelRects = [];

    for (final item in items) {
      final percentage = item.amount / total;
      final angle = percentage * 360.0;
      final midAngle = currentAngle + angle / 2;

      final radians = midAngle * (3.1415926535 / 180.0);

      // Start from the outer edge of the pie
      final x1 = center.dx + pieOuterRadius * cos(radians);
      final y1 = center.dy + pieOuterRadius * sin(radians);

      // Angled line outwards
      final x2 = center.dx + (pieOuterRadius + line1Length) * cos(radians);
      var y2 = center.dy + (pieOuterRadius + line1Length) * sin(radians);

      // Collision detection and adjustment for y2
      final isRightSide = cos(radians) >= 0;

      final percentStr = (percentage * 100).toStringAsFixed(2);
      final labelText = '${item.category.name} $percentStr%';

      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Color(0xFF5E656B),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      double labelY = y2 - textPainter.height / 2;
      double labelXCandidate = isRightSide
          ? x2 + line2Length + 4
          : x2 - line2Length - textPainter.width - 4;

      Rect currentRect = Rect.fromLTWH(
          labelXCandidate, labelY, textPainter.width, textPainter.height);

      // Simple collision avoidance: push based on side
      bool collision = true;
      int iterations = 0;
      while (collision && iterations < 20) {
        collision = false;
        for (final rect in labelRects) {
          final inflatedRect = rect.inflate(4.0);
          if (inflatedRect.overlaps(currentRect)) {
            collision = true;
            // Right side: labels go top to bottom, so push down
            // Left side: labels go bottom to top, so push up
            if (isRightSide) {
              y2 += 14; // Push down
            } else {
              y2 -= 14; // Push up
            }
            labelY = y2 - textPainter.height / 2;
            currentRect = Rect.fromLTWH(
                labelXCandidate, labelY, textPainter.width, textPainter.height);
            break;
          }
        }
        iterations++;
      }
      labelRects.add(currentRect);

      // Horizontal line
      final x3 = x2 + (isRightSide ? line2Length : -line2Length);
      final y3 = y2;

      final linePaint = Paint()
        ..color = Color(item.category.colorValue)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(x1, y1)
        ..lineTo(x2, y2)
        ..lineTo(x3, y3);

      canvas.drawPath(path, linePaint);

      double labelX;

      if (isRightSide) {
        labelX = x3 + 4;
      } else {
        labelX = x3 - textPainter.width - 4;
      }

      textPainter.paint(canvas, Offset(labelX, labelY));

      currentAngle += angle;
    }
  }

  @override
  bool shouldRepaint(_PieChartLabelPainter oldDelegate) {
    return items != oldDelegate.items || total != oldDelegate.total;
  }
}
