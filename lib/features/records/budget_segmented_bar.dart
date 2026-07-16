import 'package:flutter/material.dart';

class BudgetSegment {
  const BudgetSegment({
    required this.color,
    required this.amount,
  });

  final Color color;
  final double amount;
}

class BudgetSegmentedBar extends StatelessWidget {
  const BudgetSegmentedBar({
    super.key,
    required this.totalBudget,
    required this.segments,
    this.height = 10,
    this.backgroundColor = const Color(0x26FFFFFF),
    this.showOverflowIndicator = true,
  });

  final double totalBudget;
  final List<BudgetSegment> segments;
  final double height;
  final Color backgroundColor;
  final bool showOverflowIndicator;

  @override
  Widget build(BuildContext context) {
    final totalConsumed =
        segments.fold<double>(0.0, (sum, item) => sum + item.amount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillRatio = totalBudget <= 0 ? 0.0 : (totalConsumed / totalBudget);
        final filledWidth = (fillRatio.clamp(0.0, 1.0)) * width;
        final isOverflow = fillRatio > 1.0;

        final segmentWidgets = <Widget>[];
        var left = 0.0;
        for (final segment in segments) {
          if (segment.amount <= 0 || totalBudget <= 0) {
            continue;
          }
          final segmentWidth = (segment.amount / totalBudget) * width;
          if (left >= filledWidth) {
            break;
          }
          final clippedWidth = (left + segmentWidth > filledWidth)
              ? (filledWidth - left)
              : segmentWidth;
          if (clippedWidth <= 0) {
            continue;
          }
          segmentWidgets.add(
            Positioned(
              left: left,
              top: 0,
              bottom: 0,
              child: Container(width: clippedWidth, color: segment.color),
            ),
          );
          left += segmentWidth;
        }

        if (showOverflowIndicator && isOverflow) {
          segmentWidgets.add(
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: const Color(0xFFFF4D4F),
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: backgroundColor)),
                ...segmentWidgets,
              ],
            ),
          ),
        );
      },
    );
  }
}

