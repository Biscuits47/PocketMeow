import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('分析', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      '${formatMonthLabel(store.selectedMonth)} 的花销洞察',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _MonthSwitchCompact(store: store),
            ],
          ),
          const SizedBox(height: 20),
          _MonthComparisonCard(store: store),
          const SizedBox(height: 16),
          _SpendingDistributionCard(store: store),
          const SizedBox(height: 16),
          _TrendCard(store: store),
          const SizedBox(height: 16),
          _MonthlyHistoryCard(store: store),
          const SizedBox(height: 16),
          _InsightsSummaryCard(store: store),
        ],
      ),
    );
  }
}

class _MonthComparisonCard extends StatelessWidget {
  const _MonthComparisonCard({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月度对比', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              store.monthComparisonText,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FlowStat(
                    label: '收入',
                    value: formatShortCurrency(store.monthIncome),
                    valueColor: AppTheme.mintDeep,
                  ),
                ),
                Expanded(
                  child: _FlowStat(
                    label: '支出',
                    value: formatShortCurrency(store.monthSpent),
                    valueColor: AppTheme.warning,
                  ),
                ),
                Expanded(
                  child: _FlowStat(
                    label: '净额',
                    value: formatShortCurrency(store.monthNet),
                    valueColor: store.monthNet >= 0
                        ? AppTheme.mintDeep
                        : AppTheme.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowStat extends StatelessWidget {
  const _FlowStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

class _SpendingDistributionCard extends StatelessWidget {
  const _SpendingDistributionCard({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = store.categorySpendData.take(4).toList();
    final total = store.monthSpent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当月支出分布', style: theme.textTheme.titleLarge),
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
              SizedBox(
                height: 240,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          centerSpaceRadius: 42,
                          sectionsSpace: 2,
                          sections: items
                              .map(
                                (item) => PieChartSectionData(
                                  color: Color(item.category.colorValue),
                                  value: item.amount,
                                  radius: 56,
                                  title:
                                      '${(item.shareOf(total) * 100).round()}%',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: items
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(item.category.colorValue),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.category.name,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    Text(
                                      formatChartAmount(item.amount),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
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
      (maxValue, item) => max(
        maxValue,
        max(item.expense, item.income),
      ),
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
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final label = data[spot.x.toInt()].label;
                          final amount = formatChartTooltipAmount(spot.y);
                          return LineTooltipItem(
                            '$label\n$amount',
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topCategory =
        store.categorySpendData.isEmpty ? null : store.categorySpendData.first;
    final topDay = store.recentDailySpend.reduce(
      (a, b) => a.expense >= b.expense ? a : b,
    );
    final insights = [
      if (topCategory != null)
        '${topCategory.category.name} 是本月最大支出，占比 ${(topCategory.shareOf(store.monthSpent) * 100).round()}%',
      '最近一周 ${weekdayLabel(topDay.date.weekday)} 的支出最高，花了 ${formatShortCurrency(topDay.expense)}',
      '按当前节奏，本月预计${store.projectedBalance >= 0 ? '结余' : '超支'} ${formatShortCurrency(store.projectedBalance.abs())}',
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
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium,
                      ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('近 6 个月', style: theme.textTheme.titleLarge),
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
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = data[group.x.toInt()].label;
                        final amount = formatChartTooltipAmount(rod.toY);
                        return BarTooltipItem(
                          '$label\n$amount',
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

class _MonthSwitchCompact extends StatelessWidget {
  const _MonthSwitchCompact({required this.store});

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
          Text(formatShortMonthLabel(store.selectedMonth)),
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
