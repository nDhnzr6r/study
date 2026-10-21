import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';

class DayBarChart extends StatelessWidget {
  const DayBarChart({
    super.key,
    required this.data,
    required this.labels,
    this.height = 120,
    this.showValues = true,
  });

  final List<DayCount> data;
  final List<String> labels;
  final double height;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    var maxCount = 1;
    for (final item in data) {
      if (item.count > maxCount) maxCount = item.count;
    }
    final compact = data.length > 10;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < data.length; index++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showValues)
                        Text(
                          '${data[index].count}',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            color: data[index].count == 0
                                ? palette.textSecondary.withValues(alpha: 0.5)
                                : palette.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: data[index].count == 0
                            ? 4
                            : 8 +
                                  (data[index].count / maxCount) *
                                      (height - 36),
                        margin: EdgeInsets.symmetric(
                          horizontal: compact ? 3 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: data[index].count == 0
                              ? palette.border
                              : (index == 0
                                    ? palette.accent
                                    : palette.primary.withValues(alpha: 0.45)),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: palette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.data, this.weeks = 12});

  final List<DayCount> data;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final today = dateOnly(DateTime.now());
    final monday = addDays(today, -(today.weekday - 1));
    final start = addDays(monday, -(weeks - 1) * 7);
    final counts = {for (final item in data) dateKey(item.day): item.count};

    Color cellColor(int count) {
      if (count <= 0) return palette.surfaceAlt;
      if (count < 5) return palette.primary.withValues(alpha: 0.26);
      if (count < 10) return palette.primary.withValues(alpha: 0.48);
      if (count < 20) return palette.primary.withValues(alpha: 0.72);
      return palette.primary;
    }

    Widget cell(DateTime day) {
      if (day.isAfter(today)) {
        return const SizedBox(width: 15, height: 18);
      }
      final count = counts[dateKey(day)] ?? 0;
      return Tooltip(
        message:
            '${monthDayLabel(day)} · ${count == 0 ? '没有复习' : '$count 次复习'}',
        child: Container(
          width: 15,
          height: 15,
          margin: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            color: cellColor(count),
            borderRadius: BorderRadius.circular(3.5),
          ),
        ),
      );
    }

    final weekColumns = <Widget>[];
    final monthLabels = <String>[];
    var previousMonth = -1;
    for (var week = 0; week < weeks; week++) {
      final weekStart = addDays(start, week * 7);
      if (weekStart.month != previousMonth) {
        monthLabels.add('${weekStart.month}月');
        previousMonth = weekStart.month;
      } else {
        monthLabels.add('');
      }
      weekColumns.add(
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Column(
            children: [
              for (var day = 0; day < 7; day++) cell(addDays(weekStart, day)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 22),
            for (final label in monthLabels)
              SizedBox(
                width: 18,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: 60,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  for (var day = 0; day < 7; day++)
                    SizedBox(
                      height: 18,
                      child: Text(
                        switch (day) {
                          0 => '一',
                          2 => '三',
                          4 => '五',
                          _ => '',
                        },
                        style: TextStyle(
                          fontSize: 9.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ...weekColumns,
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '少',
              style: TextStyle(fontSize: 10, color: palette.textSecondary),
            ),
            const SizedBox(width: 6),
            for (final level in [0, 2, 7, 14, 25])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: cellColor(level),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 3),
            Text(
              '多',
              style: TextStyle(fontSize: 10, color: palette.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
