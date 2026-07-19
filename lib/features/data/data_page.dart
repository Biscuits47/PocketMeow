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
  const DataPage({
    super.key,
    this.introAnimationToken = 0,
  });

  final int introAnimationToken;

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage>
    with SingleTickerProviderStateMixin {
  RecordType _chartType = RecordType.expense;
  late final AnimationController _pieIntroController;

  @override
  void initState() {
    super.initState();
    _pieIntroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant DataPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.introAnimationToken != oldWidget.introAnimationToken) {
      _pieIntroController.forward(from: 0.0001);
    }
  }

  @override
  void dispose() {
    _pieIntroController.dispose();
    super.dispose();
  }

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
                _ReportTypeSwitch(
                  type: store.reportType,
                  onChanged: store.setReportType,
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
                _SpendingDistributionCard(
                  store: store,
                  type: _chartType,
                  introAnimation: _pieIntroController,
                ),
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

class _ReportTypeSwitch extends StatelessWidget {
  const _ReportTypeSwitch({
    required this.type,
    required this.onChanged,
  });

  final ReportType type;
  final ValueChanged<ReportType> onChanged;

  @override
  Widget build(BuildContext context) {
    const reportTypes = [
      ReportType.weekly,
      ReportType.monthly,
      ReportType.yearly,
    ];
    final selectedIndex = reportTypes.indexOf(type);

    return SizedBox(
      height: 62,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thumbWidth = (constraints.maxWidth - 10) / reportTypes.length;
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7ECEF)),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: thumbWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: thumbWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: reportTypes
                      .map(
                        (reportType) => Expanded(
                          child: _ReportTypeButton(
                            type: reportType,
                            isSelected: type == reportType,
                            onTap: () => onChanged(reportType),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportTypeButton extends StatelessWidget {
  const _ReportTypeButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final ReportType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _reportTypeMeta(type);
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            scale: isSelected ? 1 : 0.96,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isSelected ? 1 : 0.82,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    meta.icon,
                    size: 17,
                    color: isSelected ? AppTheme.ink : AppTheme.muted,
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppTheme.ink : AppTheme.muted,
                    ),
                    child: Text(meta.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportTypeMeta {
  const _ReportTypeMeta({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

_ReportTypeMeta _reportTypeMeta(ReportType type) {
  switch (type) {
    case ReportType.weekly:
      return const _ReportTypeMeta(
        label: '周报',
        icon: Icons.view_week_outlined,
      );
    case ReportType.monthly:
      return const _ReportTypeMeta(
        label: '月报',
        icon: Icons.calendar_view_month_rounded,
      );
    case ReportType.yearly:
      return const _ReportTypeMeta(
        label: '年报',
        icon: Icons.date_range_rounded,
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
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.settings_outlined),
      splashRadius: 20,
      color: AppTheme.ink,
      tooltip: '设置',
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SpendingDistributionCard extends StatelessWidget {
  const _SpendingDistributionCard({
    required this.store,
    required this.type,
    required this.introAnimation,
  });

  final PocketMeowStore store;
  final RecordType type;
  final Animation<double> introAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = store.categoryDataForType(type).toList();
    final total = items.fold(0.0, (sum, item) => sum + item.amount);
    final periodName = store.reportType == ReportType.yearly
        ? '年'
        : (store.reportType == ReportType.weekly ? '周' : '月');
    final typeName = type == RecordType.expense ? '支出' : '收入';
    final pieChartHeight = min(340.0, max(280.0, 208.0 + items.length * 14.0));

    List<CategorySpendData> pieItems = [];
    List<CategorySpendData> otherItems = [];

    for (final item in items) {
      if (total > 0 && (item.amount / total) < 0.02) {
        otherItems.add(item);
      } else if (pieItems.length >= 10) {
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
                height: 260,
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
                    height: pieChartHeight,
                    child: _PieDistributionChart(
                      items: pieItems,
                      total: total,
                      typeName: typeName,
                      introAnimation: introAnimation,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: items.map((item) {
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
                                          minHeight: 6,
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${(item.shareOf(total) * 100).toStringAsFixed(2)}%',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
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
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 22,
                                      color: AppTheme.muted,
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

class _PieDistributionChart extends StatelessWidget {
  const _PieDistributionChart({
    required this.items,
    required this.total,
    required this.typeName,
    required this.introAnimation,
  });

  final List<CategorySpendData> items;
  final double total;
  final String typeName;
  final Animation<double> introAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDirection = Directionality.of(context);
    final maxAmount = items.fold<double>(
      0,
      (currentMax, item) => max(currentMax, item.amount),
    );
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF5E656B),
          height: 1.0,
        ) ??
        const TextStyle(
          fontSize: 12,
          color: Color(0xFF5E656B),
          height: 1.0,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelEntries = _buildPieLabelEntries(
          items,
          total,
          baseLabelStyle: labelStyle,
          textDirection: textDirection,
        );
        final leftEntries = labelEntries
            .where((entry) => !entry.isRightSide)
            .toList()
          ..sort((a, b) => a.anchorY.compareTo(b.anchorY));
        final rightEntries = labelEntries
            .where((entry) => entry.isRightSide)
            .toList()
          ..sort((a, b) => a.anchorY.compareTo(b.anchorY));
        final dominantShare = total <= 0 ? 0.0 : (maxAmount / total);
        final useCompactLeaderLayout = dominantShare >= 0.68 &&
            max(leftEntries.length, rightEntries.length) >= 3;
        final baseChartSize =
            min(136.0, max(116.0, constraints.maxWidth * 0.27));
        final chartSize = useCompactLeaderLayout
            ? max(108.0, baseChartSize - 8.0)
            : baseChartSize;
        final centerSpaceRadius =
            chartSize * (useCompactLeaderLayout ? 0.38 : 0.36);
        final chartCenter = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );

        final layouts = [
          ..._buildLeaderLayouts(
            entries: leftEntries,
            isRightSide: false,
            size: constraints.biggest,
            center: chartCenter,
            chartSize: chartSize,
            totalAmount: total,
            maxAmount: maxAmount,
            useCompactLayout: useCompactLeaderLayout,
          ),
          ..._buildLeaderLayouts(
            entries: rightEntries,
            isRightSide: true,
            size: constraints.biggest,
            center: chartCenter,
            chartSize: chartSize,
            totalAmount: total,
            maxAmount: maxAmount,
            useCompactLayout: useCompactLeaderLayout,
          ),
        ];

        return AnimatedBuilder(
          animation: introAnimation,
          builder: (context, _) {
            final amountReveal = Curves.easeOutCubic.transform(
              introAnimation.value.clamp(0.0, 1.0),
            );
            return RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PieLeaderLinesPainter(
                        layouts: layouts,
                        animationValue: introAnimation.value,
                      ),
                    ),
                  ),
                  Positioned(
                    left: chartCenter.dx - chartSize / 2,
                    top: chartCenter.dy - chartSize / 2,
                    width: chartSize,
                    height: chartSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            centerSpaceRadius: centerSpaceRadius,
                            sectionsSpace: useCompactLeaderLayout ? 1.6 : 2,
                            sections: items.asMap().entries.map(
                              (entry) {
                                final itemIndex = entry.key;
                                final item = entry.value;
                                final valueReveal =
                                    _staggeredPieSectionRevealProgress(
                                  index: itemIndex,
                                  totalCount: items.length,
                                  animationValue: introAnimation.value,
                                );
                                final radiusReveal =
                                    _staggeredPieRadiusRevealProgress(
                                  index: itemIndex,
                                  totalCount: items.length,
                                  animationValue: introAnimation.value,
                                );
                                final isPrimarySlice =
                                    maxAmount > 0 && item.amount == maxAmount;
                                final baseRadius = chartSize *
                                    (useCompactLeaderLayout
                                        ? (isPrimarySlice ? 0.30 : 0.26)
                                        : (isPrimarySlice ? 0.32 : 0.28));
                                return PieChartSectionData(
                                  color: _rankedPieBlendColor(
                                    baseColor: Color(item.category.colorValue),
                                    index: itemIndex,
                                    totalCount: items.length,
                                  ).withValues(alpha: valueReveal),
                                  value: item.amount * valueReveal,
                                  radius: baseRadius *
                                      (0.76 + (radiusReveal * 0.24)),
                                  title: '',
                                );
                              },
                            ).toList(),
                          ),
                        ),
                        _PieCenterBadge(
                          typeName: typeName,
                          amountText: formatChartAmount(total * amountReveal),
                          revealProgress: amountReveal,
                          diameter: centerSpaceRadius * 2,
                        ),
                      ],
                    ),
                  ),
                  ...layouts.map(
                    (layout) {
                      final textReveal = _staggeredPieLabelRevealProgress(
                        index: layout.entry.rankIndex,
                        totalCount: items.length,
                        animationValue: introAnimation.value,
                      );
                      return Positioned(
                        left: layout.labelLeft,
                        top: layout.labelTop,
                        width: layout.labelWidth,
                        height: layout.labelHeight,
                        child: Align(
                          alignment: layout.alignRight
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            layout.entry.labelText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: layout.alignRight
                                ? TextAlign.right
                                : TextAlign.left,
                            style: layout.entry.labelStyle.copyWith(
                              color: (layout.entry.labelStyle.color ??
                                      const Color(0xFF5E656B))
                                  .withValues(alpha: textReveal),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PieCenterBadge extends StatelessWidget {
  const _PieCenterBadge({
    required this.typeName,
    required this.amountText,
    required this.revealProgress,
    required this.diameter,
  });

  final String typeName;
  final String amountText;
  final double revealProgress;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedReveal = revealProgress.clamp(0.0, 1.0);
    final badgeSize = diameter * 0.9;
    final horizontalPadding = max(8.0, badgeSize * 0.12);

    return SizedBox(
      width: badgeSize,
      height: badgeSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF6F8FA),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.92),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06 * clampedReveal),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: max(7.0, badgeSize * 0.14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                typeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.2,
                  color: AppTheme.muted.withValues(
                    alpha: 0.7 + (clampedReveal * 0.3),
                  ),
                ),
              ),
              SizedBox(height: max(4.0, badgeSize * 0.04)),
              Container(
                width: badgeSize * 0.26,
                height: 1.4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7DEE4).withValues(
                    alpha: 0.65 + (clampedReveal * 0.35),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(height: max(5.0, badgeSize * 0.06)),
              SizedBox(
                width: badgeSize - horizontalPadding * 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amountText,
                    maxLines: 1,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppTheme.ink.withValues(
                        alpha: 0.82 + (clampedReveal * 0.18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<_PieLeaderLayout> _buildLeaderLayouts({
  required List<_PieLabelEntry> entries,
  required bool isRightSide,
  required Size size,
  required Offset center,
  required double chartSize,
  required double totalAmount,
  required double maxAmount,
  required bool useCompactLayout,
}) {
  if (entries.isEmpty) {
    return const [];
  }

  final baseMinLabelGap = useCompactLayout ? 4.0 : 6.0;
  final verticalPadding = useCompactLayout ? 14.0 : 18.0;
  final normalSegmentLength = useCompactLayout ? 12.0 : 20.0;
  final horizontalSegmentLength = useCompactLayout ? 8.0 : 10.0;
  final labelGap = useCompactLayout ? 4.0 : 6.0;
  final centerGap = max(useCompactLayout ? 14.0 : 12.0,
      chartSize * (useCompactLayout ? 0.10 : 0.08));
  final desiredLayouts = <_PieLeaderLayout>[];

  for (final entry in entries) {
    final isPrimarySlice = maxAmount > 0 && entry.item.amount == maxAmount;
    final sectionRadius = chartSize *
        (useCompactLayout
            ? (isPrimarySlice ? 0.30 : 0.26)
            : (isPrimarySlice ? 0.32 : 0.28));
    final outerRadius =
        (chartSize * (useCompactLayout ? 0.38 : 0.36)) + sectionRadius;
    final radialUnit = Offset(cos(entry.angleRadians), sin(entry.angleRadians));

    final start = Offset(
      center.dx + radialUnit.dx * outerRadius,
      center.dy + radialUnit.dy * outerRadius,
    );

    final elbow = Offset(
      start.dx + radialUnit.dx * normalSegmentLength,
      start.dy + radialUnit.dy * normalSegmentLength,
    );

    final safeBoundaryX = isRightSide
        ? center.dx + outerRadius + (useCompactLayout ? 14.0 : 10.0)
        : center.dx - outerRadius - (useCompactLayout ? 14.0 : 10.0);
    final rawLineEndX = isRightSide
        ? elbow.dx + horizontalSegmentLength
        : elbow.dx - horizontalSegmentLength;
    final lineEndX = isRightSide
        ? max(rawLineEndX, safeBoundaryX)
        : min(rawLineEndX, safeBoundaryX);
    final labelLeft = isRightSide ? lineEndX + labelGap : 0.0;
    final labelWidth = isRightSide
        ? max(10.0, size.width - labelLeft)
        : max(10.0, lineEndX - labelGap);

    desiredLayouts.add(
      _PieLeaderLayout(
        entry: entry,
        alignRight: !isRightSide,
        start: start,
        bend: elbow,
        labelY: elbow.dy.clamp(
          verticalPadding + entry.labelHeight / 2,
          size.height - verticalPadding - entry.labelHeight / 2,
        ),
        lineEndX: lineEndX,
        labelLeft: labelLeft,
        labelTop: 0,
        labelHeight: entry.labelHeight,
        labelWidth: labelWidth,
      ),
    );
  }

  final upperIndexes = <int>[];
  final lowerIndexes = <int>[];

  for (var index = 0; index < desiredLayouts.length; index++) {
    if (desiredLayouts[index].entry.anchorY < 0) {
      upperIndexes.add(index);
    } else {
      lowerIndexes.add(index);
    }
  }

  final upperMaxLabelHeight = upperIndexes.isEmpty
      ? 0.0
      : upperIndexes
          .map((index) => desiredLayouts[index].labelHeight)
          .reduce(max);
  final lowerMaxLabelHeight = lowerIndexes.isEmpty
      ? 0.0
      : lowerIndexes
          .map((index) => desiredLayouts[index].labelHeight)
          .reduce(max);

  final upperMinCenterY = verticalPadding + upperMaxLabelHeight / 2;
  final upperMaxCenterY = max(
    upperMinCenterY,
    center.dy - centerGap - upperMaxLabelHeight / 2,
  );
  final upperLabelGap = _resolveLeaderLabelGap(
    count: upperIndexes.length,
    minCenterY: upperMinCenterY,
    maxCenterY: upperMaxCenterY,
    labelExtent: upperMaxLabelHeight,
    preferredGap: baseMinLabelGap,
  );
  for (var position = upperIndexes.length - 1; position >= 0; position--) {
    final index = upperIndexes[position];
    final current = desiredLayouts[index];
    final minCurrentY = verticalPadding + current.labelHeight / 2;
    final currentUpperMaxY = center.dy - centerGap - current.labelHeight / 2;
    var targetY = min(current.labelY, upperMaxCenterY);
    if (position < upperIndexes.length - 1) {
      final next = desiredLayouts[upperIndexes[position + 1]];
      final maxAllowedY = next.labelY -
          (next.labelHeight / 2) -
          (current.labelHeight / 2) -
          upperLabelGap;
      targetY = min(targetY, maxAllowedY);
    }
    desiredLayouts[index] = current.copyWith(
      labelY: max(minCurrentY, min(targetY, currentUpperMaxY)),
    );
  }
  if (_shouldRedistributeLeaderGroup(
    layouts: desiredLayouts,
    indexes: upperIndexes,
    topBoundary: verticalPadding,
    bottomBoundary: center.dy - centerGap,
    preferredGap: upperLabelGap,
  )) {
    _redistributeLeaderGroup(
      layouts: desiredLayouts,
      indexes: upperIndexes,
      topBoundary: verticalPadding,
      bottomBoundary: center.dy - centerGap,
      preferredGap: upperLabelGap,
      anchorToBottom: true,
    );
  }

  final lowerMaxCenterY =
      size.height - verticalPadding - lowerMaxLabelHeight / 2;
  final lowerMinCenterY = min(
    lowerMaxCenterY,
    center.dy + centerGap + lowerMaxLabelHeight / 2,
  );
  final lowerLabelGap = _resolveLeaderLabelGap(
    count: lowerIndexes.length,
    minCenterY: lowerMinCenterY,
    maxCenterY: lowerMaxCenterY,
    labelExtent: lowerMaxLabelHeight,
    preferredGap: baseMinLabelGap,
  );
  for (var position = 0; position < lowerIndexes.length; position++) {
    final index = lowerIndexes[position];
    final current = desiredLayouts[index];
    final maxCurrentY = size.height - verticalPadding - current.labelHeight / 2;
    final currentLowerMinY = center.dy + centerGap + current.labelHeight / 2;
    var targetY = max(current.labelY, lowerMinCenterY);
    if (position > 0) {
      final previous = desiredLayouts[lowerIndexes[position - 1]];
      final minAllowedY = previous.labelY +
          (previous.labelHeight / 2) +
          (current.labelHeight / 2) +
          lowerLabelGap;
      targetY = max(targetY, minAllowedY);
    }
    desiredLayouts[index] = current.copyWith(
      labelY: min(maxCurrentY, max(targetY, currentLowerMinY)),
    );
  }
  if (_shouldRedistributeLeaderGroup(
    layouts: desiredLayouts,
    indexes: lowerIndexes,
    topBoundary: center.dy + centerGap,
    bottomBoundary: size.height - verticalPadding,
    preferredGap: lowerLabelGap,
  )) {
    _redistributeLeaderGroup(
      layouts: desiredLayouts,
      indexes: lowerIndexes,
      topBoundary: center.dy + centerGap,
      bottomBoundary: size.height - verticalPadding,
      preferredGap: lowerLabelGap,
      anchorToBottom: false,
    );
  }

  return desiredLayouts.map(
    (layout) {
      final adjustedBend = Offset(layout.bend.dx, layout.labelY);
      return layout.copyWith(
        bend: adjustedBend,
        labelTop: layout.labelY - layout.labelHeight / 2,
      );
    },
  ).toList(growable: false);
}

double _resolveLeaderLabelGap({
  required int count,
  required double minCenterY,
  required double maxCenterY,
  required double labelExtent,
  required double preferredGap,
}) {
  if (count <= 1) {
    return preferredGap;
  }

  final availableSpan = max(0.0, maxCenterY - minCenterY);
  final maxGapThatFits = (availableSpan / (count - 1)) - labelExtent;
  return max(2.0, min(preferredGap, maxGapThatFits));
}

bool _shouldRedistributeLeaderGroup({
  required List<_PieLeaderLayout> layouts,
  required List<int> indexes,
  required double topBoundary,
  required double bottomBoundary,
  required double preferredGap,
}) {
  if (indexes.length < 3) {
    return false;
  }

  final availableSpan = max(0.0, bottomBoundary - topBoundary);
  final totalLabelHeights = indexes.fold<double>(
    0.0,
    (sum, index) => sum + layouts[index].labelHeight,
  );
  final preferredSpan = totalLabelHeights + preferredGap * (indexes.length - 1);
  final currentSpan =
      layouts[indexes.last].labelY - layouts[indexes.first].labelY;
  return preferredSpan > (availableSpan * 0.8) ||
      currentSpan < (preferredSpan * 0.8);
}

void _redistributeLeaderGroup({
  required List<_PieLeaderLayout> layouts,
  required List<int> indexes,
  required double topBoundary,
  required double bottomBoundary,
  required double preferredGap,
  required bool anchorToBottom,
}) {
  if (indexes.isEmpty) {
    return;
  }

  final availableSpan = max(0.0, bottomBoundary - topBoundary);
  final totalLabelHeights = indexes.fold<double>(
    0.0,
    (sum, index) => sum + layouts[index].labelHeight,
  );
  final fittingGap = indexes.length > 1
      ? max(1.0, (availableSpan - totalLabelHeights) / (indexes.length - 1))
      : 0.0;
  final resolvedGap =
      indexes.length > 1 ? max(1.0, min(preferredGap, fittingGap)) : 0.0;
  final totalUsed =
      totalLabelHeights + resolvedGap * max(0, indexes.length - 1);

  var currentTop = anchorToBottom
      ? max(topBoundary, bottomBoundary - totalUsed)
      : topBoundary;

  for (final index in indexes) {
    final current = layouts[index];
    final centerY = currentTop + current.labelHeight / 2;
    layouts[index] = current.copyWith(labelY: centerY);
    currentTop += current.labelHeight + resolvedGap;
  }
}

class _PieLeaderLinesPainter extends CustomPainter {
  const _PieLeaderLinesPainter({
    required this.layouts,
    required this.animationValue,
  });

  final List<_PieLeaderLayout> layouts;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    for (final layout in layouts) {
      final lineReveal = _staggeredPieLineRevealProgress(
        index: layout.entry.rankIndex,
        totalCount: layouts.length,
        animationValue: animationValue,
      );
      if (lineReveal <= 0) {
        continue;
      }
      final guidePaint = Paint()
        ..color = _rankedPieBlendColor(
          baseColor: Color(layout.entry.item.category.colorValue),
          index: layout.entry.rankIndex,
          totalCount: layouts.length,
        ).withValues(alpha: lineReveal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawAnimatedLeaderLine(canvas, layout, lineReveal, guidePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PieLeaderLinesPainter oldDelegate) {
    return oldDelegate.layouts != layouts ||
        oldDelegate.animationValue != animationValue;
  }
}

void _drawAnimatedLeaderLine(
  Canvas canvas,
  _PieLeaderLayout layout,
  double progress,
  Paint paint,
) {
  if (progress <= 0) {
    return;
  }

  const firstSegmentWeight = 0.68;
  if (progress < firstSegmentWeight) {
    final firstT = progress / firstSegmentWeight;
    final firstEnd = Offset(
      layout.start.dx + (layout.bend.dx - layout.start.dx) * firstT,
      layout.start.dy + (layout.bend.dy - layout.start.dy) * firstT,
    );
    canvas.drawLine(layout.start, firstEnd, paint);
    return;
  }

  canvas.drawLine(layout.start, layout.bend, paint);
  final secondT = (progress - firstSegmentWeight) / (1 - firstSegmentWeight);
  final secondEnd = Offset(
    layout.bend.dx + (layout.lineEndX - layout.bend.dx) * secondT,
    layout.bend.dy,
  );
  canvas.drawLine(layout.bend, secondEnd, paint);
}

List<_PieLabelEntry> _buildPieLabelEntries(
  List<CategorySpendData> items,
  double total, {
  required TextStyle baseLabelStyle,
  required TextDirection textDirection,
}) {
  var currentAngle = -90.0;
  final entries = <_PieLabelEntry>[];

  for (final entry in items.asMap().entries) {
    final index = entry.key;
    final item = entry.value;
    final share = item.shareOf(total);
    final angle = share * 360.0;
    final midAngle = currentAngle + angle / 2;
    final radians = midAngle * (pi / 180.0);
    final labelText = '${item.category.name} ${_formatPieLabelPercent(share)}%';
    final labelStyle = _resolvePieLabelStyle(baseLabelStyle, share);
    final labelPainter = TextPainter(
      text: TextSpan(text: labelText, style: labelStyle),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();
    entries.add(
      _PieLabelEntry(
        item: item,
        percentText: _formatPieLabelPercent(share),
        labelText: labelText,
        labelStyle: labelStyle,
        labelHeight: labelPainter.height + 4,
        rankIndex: index,
        isRightSide: cos(radians) >= 0,
        angleRadians: radians,
        anchorY: sin(radians),
      ),
    );
    currentAngle += angle;
  }

  return entries;
}

TextStyle _resolvePieLabelStyle(TextStyle baseStyle, double share) {
  if (share < 0.03) {
    return baseStyle.copyWith(
        fontSize: max(10.0, (baseStyle.fontSize ?? 12) - 1.5));
  }
  if (share < 0.06) {
    return baseStyle.copyWith(
        fontSize: max(10.5, (baseStyle.fontSize ?? 12) - 1));
  }
  return baseStyle;
}

String _formatPieLabelPercent(double value) {
  final percent = value * 100;
  if (percent >= 10) {
    return percent.toStringAsFixed(1);
  }
  return percent.toStringAsFixed(2);
}

Color _rankedPieBlendColor({
  required Color baseColor,
  required int index,
  required int totalCount,
}) {
  if (totalCount <= 1) {
    return baseColor;
  }

  final progress = index / (totalCount - 1);
  final easedProgress = Curves.easeInCubic.transform(progress);
  return Color.lerp(baseColor, Colors.white, easedProgress * 0.8) ?? baseColor;
}

double _staggeredPieSectionRevealProgress({
  required int index,
  required int totalCount,
  required double animationValue,
}) {
  final window = _pieAnimationWindow(
    index: index,
    totalCount: totalCount,
  );
  return _curveProgress(
    animationValue: animationValue,
    start: window.start,
    end: window.start + (window.length * 0.72),
    curve: Curves.easeOutCubic,
  );
}

double _staggeredPieRadiusRevealProgress({
  required int index,
  required int totalCount,
  required double animationValue,
}) {
  final window = _pieAnimationWindow(
    index: index,
    totalCount: totalCount,
  );
  return _curveProgress(
    animationValue: animationValue,
    start: window.start,
    end: window.start + (window.length * 0.76),
    curve: Curves.easeOutBack,
  ).clamp(0.0, 1.12);
}

double _staggeredPieLineRevealProgress({
  required int index,
  required int totalCount,
  required double animationValue,
}) {
  final window = _pieAnimationWindow(
    index: index,
    totalCount: totalCount,
  );
  return _curveProgress(
    animationValue: animationValue,
    start: window.start + (window.length * 0.4),
    end: window.start + (window.length * 0.92),
    curve: Curves.easeOutCubic,
  );
}

double _staggeredPieLabelRevealProgress({
  required int index,
  required int totalCount,
  required double animationValue,
}) {
  final window = _pieAnimationWindow(
    index: index,
    totalCount: totalCount,
  );
  return _curveProgress(
    animationValue: animationValue,
    start: window.start + (window.length * 0.62),
    end: window.end,
    curve: Curves.easeOutCubic,
  );
}

_PieAnimationWindow _pieAnimationWindow({
  required int index,
  required int totalCount,
}) {
  if (totalCount <= 1) {
    return const _PieAnimationWindow(start: 0, end: 1);
  }

  const itemWindowLength = 0.44;
  final staggerSpan = 1.0 - itemWindowLength;
  final start = (index / (totalCount - 1)) * staggerSpan;
  return _PieAnimationWindow(
    start: start,
    end: min(1.0, start + itemWindowLength),
  );
}

double _curveProgress({
  required double animationValue,
  required double start,
  required double end,
  required Curve curve,
}) {
  if (end <= start) {
    return animationValue >= end ? 1.0 : 0.0;
  }

  final normalized = ((animationValue.clamp(0.0, 1.0) - start) / (end - start))
      .clamp(0.0, 1.0);
  return curve.transform(normalized);
}

class _PieLabelEntry {
  const _PieLabelEntry({
    required this.item,
    required this.percentText,
    required this.labelText,
    required this.labelStyle,
    required this.labelHeight,
    required this.rankIndex,
    required this.isRightSide,
    required this.angleRadians,
    required this.anchorY,
  });

  final CategorySpendData item;
  final String percentText;
  final String labelText;
  final TextStyle labelStyle;
  final double labelHeight;
  final int rankIndex;
  final bool isRightSide;
  final double angleRadians;
  final double anchorY;
}

class _PieAnimationWindow {
  const _PieAnimationWindow({
    required this.start,
    required this.end,
  });

  final double start;
  final double end;

  double get length => end - start;
}

class _PieLeaderLayout {
  const _PieLeaderLayout({
    required this.entry,
    required this.alignRight,
    required this.start,
    required this.bend,
    required this.labelY,
    required this.lineEndX,
    required this.labelLeft,
    required this.labelTop,
    required this.labelHeight,
    required this.labelWidth,
  });

  final _PieLabelEntry entry;
  final bool alignRight;
  final Offset start;
  final Offset bend;
  final double labelY;
  final double lineEndX;
  final double labelLeft;
  final double labelTop;
  final double labelHeight;
  final double labelWidth;

  _PieLeaderLayout copyWith({
    _PieLabelEntry? entry,
    bool? alignRight,
    Offset? start,
    Offset? bend,
    double? labelY,
    double? lineEndX,
    double? labelLeft,
    double? labelTop,
    double? labelHeight,
    double? labelWidth,
  }) {
    return _PieLeaderLayout(
      entry: entry ?? this.entry,
      alignRight: alignRight ?? this.alignRight,
      start: start ?? this.start,
      bend: bend ?? this.bend,
      labelY: labelY ?? this.labelY,
      lineEndX: lineEndX ?? this.lineEndX,
      labelLeft: labelLeft ?? this.labelLeft,
      labelTop: labelTop ?? this.labelTop,
      labelHeight: labelHeight ?? this.labelHeight,
      labelWidth: labelWidth ?? this.labelWidth,
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
    final includedRecords = store.currentMonthRecords
        .where((record) => !record.excludeFromBudget)
        .toList();
    final includedExpenses = includedRecords
        .where((record) => record.type == RecordType.expense)
        .toList();
    final includedIncomes = includedRecords
        .where((record) => record.type == RecordType.income)
        .toList();
    final topCategory = _buildSummaryTopCategory(store, includedExpenses);

    final periodName = store.reportType == ReportType.yearly
        ? '年'
        : (store.reportType == ReportType.weekly ? '周' : '月');

    final currentExp =
        includedExpenses.fold(0.0, (sum, record) => sum + record.amount);
    final currentInc =
        includedIncomes.fold(0.0, (sum, record) => sum + record.amount);
    final useBudgetBalance = store.reportType == ReportType.monthly;
    final currentBalance =
        useBudgetBalance ? store.remainingBudget : currentInc - currentExp;

    final prevExp = store.previousPeriodExpense;
    final prevInc = store.previousPeriodIncome;

    final balanceText = currentBalance >= 0
        ? '${useBudgetBalance ? '预算结余' : '结余'} ${formatShortCurrency(currentBalance)}'
        : '${useBudgetBalance ? '预算超支' : '超支'} ${formatShortCurrency(currentBalance.abs())}';

    final salaryAndBonus = includedIncomes.where((r) {
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

    if (includedRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('智能总结', style: theme.textTheme.titleLarge),
              const SizedBox(height: 14),
              Text(
                '当前统计会自动忽略“不计入预算”的交易，暂时没有可用于分析的数据。',
                style: defaultStyle.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      );
    }

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
        TextSpan(text: topCategory.name.trim(), style: boldStyle),
        TextSpan(
            text:
                '是本$periodName最大支出，占总支出的 ${currentExp == 0 ? 0 : ((topCategory.amount / currentExp) * 100).round()}%'),
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

class _SummaryTopCategory {
  const _SummaryTopCategory({
    required this.name,
    required this.amount,
  });

  final String name;
  final double amount;
}

_SummaryTopCategory? _buildSummaryTopCategory(
  PocketMeowStore store,
  List<ExpenseRecord> expenses,
) {
  if (expenses.isEmpty) {
    return null;
  }

  final amountByCategory = <String, double>{};
  for (final expense in expenses) {
    amountByCategory[expense.categoryId] =
        (amountByCategory[expense.categoryId] ?? 0) + expense.amount;
  }

  final topEntry = amountByCategory.entries.reduce(
    (current, next) => current.value >= next.value ? current : next,
  );
  final category = store.categoryById(topEntry.key);
  return _SummaryTopCategory(
    name: category?.name ?? '未分类',
    amount: topEntry.value,
  );
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
