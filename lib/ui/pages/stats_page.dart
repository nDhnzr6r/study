import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.store});

  final StudyStore store;

  @override
  Widget build(BuildContext context) {
    final overview = store.overview;
    if (overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final palette = AppColors.of(context);
    final maturity = overview.totalCards == 0
        ? 0.0
        : overview.matureCards / overview.totalCards;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '统计', subtitle: '从复习记录里看节奏，也看记忆留下的痕迹。'),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 1020
                  ? 4
                  : width >= 620
                  ? 2
                  : 1;
              const spacing = 16.0;
              final tileWidth = (width - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: StatTile(
                      label: '总卡片',
                      value: '${overview.totalCards}',
                      hint: '分布在 ${store.decks.length} 个卡组',
                      icon: Icons.style_rounded,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: StatTile(
                      label: '已掌握',
                      value: '${overview.matureCards}',
                      hint: overview.totalCards == 0
                          ? '还没有卡片'
                          : '占全部卡片的 ${percentLabel(maturity)}',
                      icon: Icons.verified_outlined,
                      accent: palette.success,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: StatTile(
                      label: '30 天保持率',
                      value: percentLabel(overview.retention),
                      hint: '评分不为「忘记」的比例',
                      icon: Icons.trending_up_rounded,
                      accent: palette.info,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: StatTile(
                      label: '连续学习',
                      value: '${overview.streak} 天',
                      hint: '每天复习一点，间隔会逐渐拉长',
                      icon: Icons.local_fire_department_outlined,
                      accent: palette.accent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final load = SectionCard(
                title: '复习负荷',
                subtitle: '未来 14 天每天到期的卡片',
                child: DayBarChart(
                  data: store.forecast,
                  labels: [
                    for (var index = 0; index < store.forecast.length; index++)
                      index == 0
                          ? '今天'
                          : shortWeekdayLabel(store.forecast[index].day),
                  ],
                  height: 148,
                  showValues: true,
                ),
              );
              final states = SectionCard(
                title: '卡片状态',
                subtitle: '按当前复习间隔划分',
                child: _MaturityPanel(overview: overview),
              );
              if (!wide) {
                return Column(
                  children: [load, const SizedBox(height: 20), states],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: load),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: states),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: '学习记录',
            subtitle: '最近 12 周每天完成的复习次数',
            child: ActivityHeatmap(data: store.heatmap),
          ),
        ],
      ),
    );
  }
}

class _MaturityPanel extends StatelessWidget {
  const _MaturityPanel({required this.overview});

  final OverviewData overview;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final total = overview.totalCards;
    final segments = <_MaturitySegment>[
      _MaturitySegment(
        '新卡',
        overview.newTotal,
        palette.textSecondary.withValues(alpha: 0.35),
      ),
      _MaturitySegment('学习中', overview.learningCards, palette.warning),
      _MaturitySegment('巩固中', overview.youngCards, palette.info),
      _MaturitySegment('已掌握', overview.matureCards, palette.primary),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: total == 0
                ? Container(color: palette.surfaceAlt)
                : Row(
                    children: [
                      for (final segment in segments)
                        if (segment.count > 0)
                          Expanded(
                            flex: segment.count,
                            child: Container(color: segment.color),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        for (final segment in segments) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: segment.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    segment.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${segment.count}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          '间隔达到 21 天后计为已掌握。',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.5,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MaturitySegment {
  const _MaturitySegment(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}
