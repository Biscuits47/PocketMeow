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

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  RecordType _chartType = RecordType.expense;

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
                    _PeriodSwitchCompact(store: store),
                    _TypeSwitchCompact(
                      type: _chartType,
                      onChanged: (type) {
                        setState(() {
                          _chartType = type;
                        });
                      },
                    ),
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
                _SpendingDistributionCard(store: store, type: _chartType),
                const SizedBox(height: 16),
                _TrendCard(store: store, type: _chartType),
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

class _TypeSwitchCompact extends StatelessWidget {
  const _TypeSwitchCompact({
    required this.type,
    required this.onChanged,
  });

  final RecordType type;
  final ValueChanged<RecordType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TypeButton(
            label: '支出',
            isSelected: type == RecordType.expense,
            onTap: () => onChanged(RecordType.expense),
          ),
          _TypeButton(
            label: '收入',
            isSelected: type == RecordType.income,
            onTap: () => onChanged(RecordType.income),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.ink : AppTheme.muted,
              ),
        ),
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
  const _SpendingDistributionCard({required this.store, required this.type});

  final PocketMeowStore store;
  final RecordType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = store.categoryDataForType(type);
    final total =
        type == RecordType.expense ? store.monthSpent : store.monthIncome;
    final periodName = store.reportType == ReportType.yearly
        ? '年'
        : (store.reportType == ReportType.weekly ? '周' : '月');
    final typeName = type == RecordType.expense ? '支出' : '收入';

    List<CategorySpendData> pieItems = [];
    List<CategorySpendData> otherItems = [];

    for (final item in items) {
      if (total > 0 && (item.amount / total) < 0.10) {
        otherItems.add(item);
      } else {
        pieItems.add(item);
      }
    }

    if (otherItems.isNotEmpty) {
      if (otherItems.length == 1) {
        pieItems.add(otherItems.first);
      } else {
        double otherAmount =
            otherItems.fold(0.0, (sum, item) => sum + item.amount);
        int otherCount = otherItems.fold(0, (sum, item) => sum + item.count);

        pieItems.add(CategorySpendData(
          category: ExpenseCategory(
            id: 'other_combined',
            name: '其他',
            iconKey: 'more_horiz',
            colorValue: 0xFFB0BEC5, // Grey color for 'Other'
            limit: 0,
            type: type,
            isSystem: true,
          ),
          amount: otherAmount,
          count: otherCount,
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当$periodName$typeName分布', style: theme.textTheme.titleLarge),
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

class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.store, required this.type});

  final PocketMeowStore store;
  final RecordType type;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  int? _touchedIndex;

  @override
  void didUpdateWidget(_TrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.reportType != widget.store.reportType ||
        oldWidget.type != widget.type) {
      _touchedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.store.periodTrendData;
    final isExpense = widget.type == RecordType.expense;

    final maxAmount = data.fold<double>(
      0,
      (maxValue, item) => max(maxValue, isExpense ? item.expense : item.income),
    );

    final typeName = isExpense ? '消费' : '收入';
    final title = widget.store.reportType == ReportType.yearly
        ? '年度$typeName趋势'
        : (widget.store.reportType == ReportType.monthly
            ? '月度$typeName趋势'
            : '本周$typeName趋势');

    final lineColor = isExpense ? AppTheme.warning : AppTheme.mintDeep;
    final fillColor = isExpense
        ? AppTheme.warning.withValues(alpha: 0.12)
        : AppTheme.mint.withValues(alpha: 0.12);

    final barData = LineChartBarData(
      isCurved: false,
      preventCurveOverShooting: true,
      color: lineColor,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: fillColor,
      ),
      spots: List.generate(
        data.length,
        (index) => FlSpot(index.toDouble(),
            isExpense ? data[index].expense : data[index].income),
      ),
    );

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
                  showingTooltipIndicators:
                      _touchedIndex != null && _touchedIndex! < data.length
                          ? [
                              ShowingTooltipIndicators([
                                LineBarSpot(
                                    barData, 0, barData.spots[_touchedIndex!]),
                              ])
                            ]
                          : [],
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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: maxAmount == 0 ? 25 : maxAmount / 4,
                        getTitlesWidget: (value, meta) {
                          // Avoid showing the max/min edge if it overlaps, but generally FlChart handles it.
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              formatChartTooltipAmount(value, noDecimal: true),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: AppTheme.muted,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
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
                          if (widget.store.reportType == ReportType.monthly) {
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
                    handleBuiltInTouches: false,
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      if (event is FlTapUpEvent || event is FlPanDownEvent) {
                        if (touchResponse?.lineBarSpots != null &&
                            touchResponse!.lineBarSpots!.isNotEmpty) {
                          setState(() {
                            _touchedIndex =
                                touchResponse.lineBarSpots![0].spotIndex;
                          });
                        } else {
                          setState(() {
                            _touchedIndex = null;
                          });
                        }
                      }
                    },
                    getTouchedSpotIndicator:
                        (LineChartBarData barData, List<int> spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          const FlLine(
                              color: Color(0xFFE8EDF0), strokeWidth: 2),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: lineColor,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final label = data[spot.x.toInt()].label;
                          final amount = formatChartTooltipAmount(spot.y);
                          final prefix = isExpense ? '支出: ' : '收入: ';
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
                  lineBarsData: [barData],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _LegendDot(color: lineColor, label: isExpense ? '支出' : '收入'),
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
    final useBudgetBalance = store.reportType == ReportType.monthly;
    final currentBalance =
        useBudgetBalance ? store.remainingBudget : currentInc - currentExp;

    final prevExp = store.previousPeriodExpense;
    final prevInc = store.previousPeriodIncome;

    final balanceText = currentBalance >= 0
        ? '${useBudgetBalance ? '预算结余' : '结余'} ${formatShortCurrency(currentBalance)}'
        : '${useBudgetBalance ? '预算超支' : '超支'} ${formatShortCurrency(currentBalance.abs())}';

    final salaryAndBonus = store.currentMonthIncomes.where((r) {
      final cat = store.categoryById(r.categoryId);
      return cat?.name == '工资' ||
          cat?.name == '奖金' ||
          r.categoryId == 'salary' ||
          r.categoryId == 'bonus';
    }).fold(0.0, (sum, r) => sum + r.amount);

    String thirdInsight;
    if (useBudgetBalance) {
      if (store.totalBudget <= 0) {
        thirdInsight = '本$periodName共支出 ${formatShortCurrency(currentExp)}。';
      } else {
        thirdInsight =
            '本$periodName$balanceText，预算已用 ${(store.budgetUsage * 100).round()}%。';
      }
    } else if (currentInc == 0) {
      thirdInsight = '本$periodName共支出 ${formatShortCurrency(currentExp)}。';
    } else {
      thirdInsight =
          '本$periodName$balanceText，支出占收入的 ${((currentExp / currentInc) * 100).round()}%。';
    }

    final insights = <InlineSpan>[];
    final defaultStyle = theme.textTheme.bodyMedium!;
    final boldStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);

    if (store.reportType == ReportType.yearly) {
      insights.add(TextSpan(children: [
        TextSpan(text: '本年度总收入为 ${formatShortCurrency(currentInc)}，其中'),
        TextSpan(text: '工资', style: boldStyle),
        const TextSpan(text: '和'),
        TextSpan(text: '奖金', style: boldStyle),
        TextSpan(
            text:
                '收入为 ${formatShortCurrency(salaryAndBonus)}，总支出为 ${formatShortCurrency(currentExp)}。'),
      ]));
    }
    if (topCategory != null) {
      insights.add(TextSpan(children: [
        TextSpan(text: topCategory.category.name.trim(), style: boldStyle),
        TextSpan(
            text:
                '是本$periodName最大支出，占总支出的 ${(topCategory.shareOf(store.monthSpent) * 100).round()}%'),
      ]));
    }
    insights.add(TextSpan(
        text:
            '与上$periodName相比，${_formatComparison(currentExp, prevExp, '支出')}，${_formatComparison(currentInc, prevInc, '收入')}。'));
    insights.add(TextSpan(text: thirdInsight));

    if (store.reportType == ReportType.yearly &&
        store.selectedDate.year == DateTime.now().year) {
      final now = DateTime.now();
      double forecastIncome = 0;
      bool hasData = false;

      final currentYearRecords = store.records.where((r) =>
          r.type == RecordType.income &&
          !r.excludeFromBudget &&
          r.createdAt.year == now.year);

      // Find salary and bonus records for the year
      final salaryBonusRecords = currentYearRecords.where((r) {
        final cat = store.categoryById(r.categoryId);
        return cat?.name == '工资' ||
            cat?.name == '奖金' ||
            r.categoryId == 'salary' ||
            r.categoryId == 'bonus';
      }).toList();

      if (now.month > 1) {
        // Calculate total income so far
        final totalIncomeSoFar =
            currentYearRecords.fold(0.0, (sum, r) => sum + r.amount);

        // Count how many months have salary/bonus
        final monthsWithSalary = <int>{};
        double totalSalaryBonus = 0;

        for (final r in salaryBonusRecords) {
          monthsWithSalary.add(r.createdAt.month);
          totalSalaryBonus += r.amount;
        }

        final avgMonthlySalary = monthsWithSalary.isNotEmpty
            ? totalSalaryBonus / monthsWithSalary.length
            : 0.0;

        // For remaining months (including current month if it doesn't have salary yet)
        int remainingMonths = 12 - now.month;
        if (!monthsWithSalary.contains(now.month)) {
          remainingMonths += 1;
        }

        forecastIncome =
            totalIncomeSoFar + (avgMonthlySalary * remainingMonths);
        hasData = totalIncomeSoFar > 0;
      } else {
        // It's January. Look at last year.
        final lastYearRecords = store.records.where((r) =>
            r.type == RecordType.income &&
            !r.excludeFromBudget &&
            r.createdAt.year == now.year - 1);

        if (lastYearRecords.isNotEmpty) {
          final lastYearSalaryRecords = lastYearRecords.where((r) {
            final cat = store.categoryById(r.categoryId);
            return cat?.name == '工资' ||
                cat?.name == '奖金' ||
                r.categoryId == 'salary' ||
                r.categoryId == 'bonus';
          }).toList();

          final monthsWithSalary = <int>{};
          double totalLastYearSalary = 0;
          for (final r in lastYearSalaryRecords) {
            monthsWithSalary.add(r.createdAt.month);
            totalLastYearSalary += r.amount;
          }

          final avgLastYearSalary = monthsWithSalary.isNotEmpty
              ? totalLastYearSalary / monthsWithSalary.length
              : 0.0;

          final currentJanIncome =
              currentYearRecords.fold(0.0, (sum, r) => sum + r.amount);

          int remainingMonths = 11;
          if (!salaryBonusRecords.any((r) => r.createdAt.month == 1)) {
            remainingMonths += 1;
          }

          forecastIncome =
              currentJanIncome + (avgLastYearSalary * remainingMonths);
          hasData = forecastIncome > 0;
        }
      }

      if (hasData && forecastIncome > 0) {
        insights.add(TextSpan(
            text:
                '按目前的平均收入情况，预计今年总收入约为 ${formatShortCurrency(forecastIncome)}。'));
      }
    }

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
                      child: Text.rich(
                        item,
                        style: defaultStyle,
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
    builder: (_) => _CategoryRecordsSheet(
      category: category,
    ),
  );
}

class _CategoryRecordsSheet extends StatefulWidget {
  const _CategoryRecordsSheet({
    required this.category,
  });

  final ExpenseCategory category;

  @override
  State<_CategoryRecordsSheet> createState() => _CategoryRecordsSheetState();
}

class _CategoryRecordsSheetState extends State<_CategoryRecordsSheet> {
  bool _sortByAmount = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListenableBuilder(
            listenable: PocketMeowScope.read(context),
            builder: (context, _) {
              final store = PocketMeowScope.read(context);
              final records = store.currentMonthRecords
                  .where((r) => r.categoryId == widget.category.id)
                  .toList();

              if (records.isEmpty) {
                return Center(
                  child: Text('没有记录', style: theme.textTheme.bodyLarge),
                );
              }

              Widget listContent;

              if (_sortByAmount) {
                final sortedRecords = List<ExpenseRecord>.from(records)
                  ..sort((a, b) => b.amount.compareTo(a.amount));

                listContent = ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  itemCount: sortedRecords.length,
                  itemBuilder: (context, index) {
                    final record = sortedRecords[index];
                    final dateStr =
                        '${record.createdAt.month}/${record.createdAt.day}';
                    final timeStr =
                        '${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}';
                    final item = RecordItem(
                      id: record.id,
                      title: widget.category.name,
                      category: widget.category.name,
                      amount: record.amount,
                      time: '$dateStr $timeStr',
                      iconKey: widget.category.iconKey,
                      record: record,
                      type: record.type,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: RecordRow(
                        item: item,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                AddExpenseSheet(expense: item.record),
                          );
                        },
                      ),
                    );
                  },
                );
              } else {
                // 按天分组
                final Map<DateTime, List<ExpenseRecord>> grouped = {};
                for (final record in records) {
                  final date = DateTime(
                    record.createdAt.year,
                    record.createdAt.month,
                    record.createdAt.day,
                  );
                  grouped.putIfAbsent(date, () => []).add(record);
                }

                final sortedKeys = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                listContent = ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final date = sortedKeys[index];
                    final items = grouped[date]!
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 8, bottom: 8, top: 16),
                          child: Text(
                            formatDayLabel(date),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...items.map((record) {
                          final item = RecordItem(
                            id: record.id,
                            title: widget.category.name,
                            category: widget.category.name,
                            amount: record.amount,
                            time:
                                '${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}',
                            iconKey: widget.category.iconKey,
                            record: record,
                            type: record.type,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: RecordRow(
                              item: item,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              onTap: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) =>
                                      AddExpenseSheet(expense: item.record),
                                );
                              },
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              }

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(widget.category.colorValue)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconForCategory(widget.category.iconKey),
                            color: Color(widget.category.colorValue),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.category.name,
                                  style: theme.textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                '共 ${records.length} 笔记录',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _sortByAmount = !_sortByAmount;
                            });
                          },
                          icon: const Icon(Icons.sort, size: 18),
                          label: Text(_sortByAmount ? '按金额' : '按时间'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.muted,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: AppTheme.muted,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: listContent,
                  ),
                ],
              );
            },
          ),
        );
      },
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

      // Clamp to prevent going out of bounds
      final double maxY = (size.height - textPainter.height) > 0
          ? size.height - textPainter.height
          : 0.0;
      final double maxX = (size.width - textPainter.width) > 0
          ? size.width - textPainter.width
          : 0.0;
      labelY = labelY.clamp(0.0, maxY);
      labelXCandidate = labelXCandidate.clamp(0.0, maxX);
      y2 = labelY + textPainter.height / 2;

      currentRect = Rect.fromLTWH(
          labelXCandidate, labelY, textPainter.width, textPainter.height);
      labelRects.add(currentRect);

      // Horizontal line
      final x3 = isRightSide
          ? labelXCandidate - 4
          : labelXCandidate + textPainter.width + 4;
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

      textPainter.paint(canvas, Offset(labelXCandidate, labelY));

      currentAngle += angle;
    }
  }

  @override
  bool shouldRepaint(_PieChartLabelPainter oldDelegate) {
    return items != oldDelegate.items || total != oldDelegate.total;
  }
}
