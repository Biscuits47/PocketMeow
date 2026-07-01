import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../settings/settings_page.dart';

class DataPage extends StatelessWidget {
  const DataPage({super.key});

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
                    Text(
                      '钱喵',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('数据', style: theme.textTheme.headlineMedium),
                  ],
                ),
              ),
              _PeriodSwitchCompact(store: store),
              const SizedBox(width: 10),
              _SettingsShortcut(onTap: () => openSettingsPage(context)),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<ReportType>(
            segments: const [
              ButtonSegment(value: ReportType.weekly, label: Text('周报')),
              ButtonSegment(value: ReportType.monthly, label: Text('月报')),
              ButtonSegment(value: ReportType.yearly, label: Text('年报')),
            ],
            selected: {store.reportType},
            onSelectionChanged: (set) {
              store.setReportType(set.first);
            },
          ),
          const SizedBox(height: 20),
          Text(
            formatPeriodLabel(store.selectedDate, store.reportType),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          _OverviewCard(theme: theme, store: store),
          const SizedBox(height: 16),
          _QuickStatsGrid(store: store),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: '图表分析',
            subtitle: '支出分布、短期趋势和月度历史放在一起看更直观。',
          ),
          const SizedBox(height: 12),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
        ),
      ],
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.theme,
    required this.store,
  });

  final ThemeData theme;
  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    final periodName = store.reportType == ReportType.yearly
        ? '年'
        : (store.reportType == ReportType.weekly ? '周' : '月');

    return InkWell(
      onTap: () => showBudgetDialog(context, store),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF162127), Color(0xFF21493F)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当$periodName总览',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                formatCurrency(store.monthNet.abs()),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                store.monthNet >= 0
                    ? '本$periodName净结余 ${formatShortCurrency(store.monthNet)}'
                    : '本$periodName净支出 ${formatShortCurrency(store.monthNet.abs())}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: store.budgetUsage,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    store.budgetUsage >= 1.0
                        ? AppTheme.warning
                        : Color.lerp(AppTheme.mint, AppTheme.warning,
                                store.budgetUsage) ??
                            AppTheme.mint,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MetricBlock(
                      label: '本$periodName收入',
                      value: formatShortCurrency(store.monthIncome),
                    ),
                  ),
                  Expanded(
                    child: _MetricBlock(
                      label: '本$periodName支出',
                      value: formatShortCurrency(store.monthSpent),
                    ),
                  ),
                  Expanded(
                    child: _MetricBlock(
                      label: '总预算',
                      value: formatShortCurrency(store.totalBudget),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  const _QuickStatsGrid({required this.store});

  final PocketMeowStore store;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final forecastText = store.projectedBalance >= 0 ? '预计结余' : '预计超支';
        final periodName = store.reportType == ReportType.yearly
            ? '年'
            : (store.reportType == ReportType.weekly ? '周' : '月');

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickStatCard(
              width: cardWidth,
              icon: Icons.arrow_downward_rounded,
              title: '本$periodName收入',
              value: formatShortCurrency(store.monthIncome),
              tone: AppTheme.mintDeep,
            ),
            _QuickStatCard(
              width: cardWidth,
              icon: Icons.arrow_upward_rounded,
              title: '本$periodName支出',
              value: formatShortCurrency(store.monthSpent),
              tone: AppTheme.warning,
            ),
            _QuickStatCard(
              width: cardWidth,
              icon: Icons.account_balance_wallet_outlined,
              title: '预算剩余',
              value: formatShortCurrency(store.remainingBudget),
              tone: AppTheme.ink,
            ),
            _QuickStatCard(
              width: cardWidth,
              icon: Icons.insights_outlined,
              title: forecastText,
              value: formatShortCurrency(store.projectedBalance.abs()),
              tone: store.projectedBalance >= 0
                  ? AppTheme.mintDeep
                  : AppTheme.warning,
            ),
          ],
        );
      },
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.tone,
  });

  final double width;
  final IconData icon;
  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9EEF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.58),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
          ),
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
    final periodName = store.reportType == ReportType.yearly
        ? '年'
        : (store.reportType == ReportType.weekly ? '周' : '月');

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
              SizedBox(
                height: 240,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
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
                                      formatShortCurrency(item.amount),
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
    final data = store.recentDailySpend;
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
            Text('近一周消费趋势', style: theme.textTheme.titleLarge),
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
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              weekdayLabel(data[index].date.weekday),
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
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
                      isCurved: true,
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
        '${topCategory.category.name} 是本期最大支出，占比 ${(topCategory.shareOf(store.monthSpent) * 100).round()}%',
      '最近一周 ${weekdayLabel(topDay.date.weekday)} 的支出最高，花了 ${formatShortCurrency(topDay.expense)}',
      '按当前节奏，本期预计${store.projectedBalance >= 0 ? '结余' : '超支'} ${formatShortCurrency(store.projectedBalance.abs())}',
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
    final data = store.recentMonthlySpend;
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
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              formatShortMonthLabel(data[index].month),
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
