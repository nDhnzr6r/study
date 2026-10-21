import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.store,
    required this.onOpenDecks,
  });

  final StudyStore store;
  final VoidCallback onOpenDecks;

  @override
  Widget build(BuildContext context) {
    final overview = store.overview;
    if (overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final palette = AppColors.of(context);
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: '今日', subtitle: fullDateLabel(DateTime.now())),
          const SizedBox(height: 26),
          if (overview.totalCards == 0)
            SurfaceCard(
              child: EmptyState(
                icon: Icons.auto_stories_outlined,
                title: '先建立一组卡片',
                message: '把要记住的内容写进卡片，之后按遗忘曲线每天复习。',
                actionLabel: '前往卡片库',
                actionIcon: Icons.arrow_forward_rounded,
                onAction: onOpenDecks,
              ),
            )
          else ...[
            _TodayPanel(
              store: store,
              overview: overview,
              onOpenDecks: onOpenDecks,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 860;
                final forecast = SectionCard(
                  title: '未来 7 天',
                  subtitle: '每天到期的卡片数量',
                  child: DayBarChart(
                    data: overview.forecast,
                    labels: [
                      for (
                        var index = 0;
                        index < overview.forecast.length;
                        index++
                      )
                        index == 0
                            ? '今天'
                            : shortWeekdayLabel(overview.forecast[index].day),
                    ],
                    height: 150,
                  ),
                );
                final decks = SectionCard(
                  title: '卡组进度',
                  subtitle: '已掌握指间隔达到 21 天以上',
                  trailing: TextButton(
                    onPressed: onOpenDecks,
                    child: const Text('全部卡组'),
                  ),
                  child: _DeckProgressList(
                    decks: store.decks,
                    onOpenDecks: onOpenDecks,
                  ),
                );
                if (!wide) {
                  return Column(
                    children: [forecast, const SizedBox(height: 20), decks],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: forecast),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: decks),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              '复习间隔会随每次评分调整，忘记的卡片会更早回来。',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.store,
    required this.overview,
    required this.onOpenDecks,
  });

  final StudyStore store;
  final OverviewData overview;
  final VoidCallback onOpenDecks;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final remainingNew = overview.remainingNew(store.dailyNewLimit);
    final hasWork = overview.dueCount > 0 || remainingNew > 0;
    final progress = overview.progress(store.dailyNewLimit);
    final actionLabel = overview.dueCount > 0
        ? '开始复习'
        : remainingNew > 0
        ? '学习新卡'
        : '今日已完成';

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.wb_sunny_outlined, size: 16, color: palette.primary),
            const SizedBox(width: 7),
            Text(
              '今日计划',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 10),
            if (!hasWork)
              StatusPill(
                label: '全部完成',
                color: palette.success,
                icon: Icons.check_rounded,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${overview.dueCount}',
              style: TextStyle(
                fontSize: 58,
                height: 0.95,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '张待复习',
                style: TextStyle(fontSize: 15, color: palette.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '新学 $remainingNew 张 · 今日已复习 ${overview.reviewedToday} 次',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        ProgressBar(value: progress, height: 8),
        const SizedBox(height: 22),
        Row(
          children: [
            FilledButton.icon(
              onPressed: hasWork
                  ? () async {
                      final started = await store.startSession();
                      if (!context.mounted) return;
                      if (!started) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('今天没有待学习的内容')),
                        );
                      }
                    }
                  : null,
              icon: Icon(
                hasWork ? Icons.play_arrow_rounded : Icons.check_rounded,
                size: 19,
              ),
              label: Text(actionLabel),
            ),
            if (!hasWork) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onOpenDecks,
                child: const Text('查看卡片库'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 26),
        Divider(color: palette.border),
        const SizedBox(height: 18),
        Row(
          children: [
            _MetaItem(label: '连续学习', value: '${overview.streak} 天'),
            const SizedBox(width: 34),
            _MetaItem(label: '今日复习', value: '${overview.reviewedToday} 张'),
            const SizedBox(width: 34),
            _MetaItem(
              label: '30 天保持率',
              value: percentLabel(overview.retention),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primarySoft, palette.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                main,
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ProgressRing(value: progress),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 28),
              _ProgressRing(value: progress),
            ],
          );
        },
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: palette.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return SizedBox(
      width: 126,
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: palette.surface.withValues(alpha: 0.8),
              color: palette.primary,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                percentLabel(value),
                style: TextStyle(
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '今日进度',
                style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeckProgressList extends StatelessWidget {
  const _DeckProgressList({required this.decks, required this.onOpenDecks});

  final List<DeckSummary> decks;
  final VoidCallback onOpenDecks;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    if (decks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有卡组',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onOpenDecks, child: const Text('新建卡组')),
        ],
      );
    }
    final visible = decks.take(4).toList();
    return Column(
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0)
            Divider(color: palette.border.withValues(alpha: 0.7), height: 20),
          InkWell(
            onTap: onOpenDecks,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? palette.accent
                          : palette.primary.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visible[index].deck.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${visible[index].mature}/${visible[index].total} 已掌握 · ${visible[index].due} 待复习',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: ProgressBar(
                      value: visible[index].maturity,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      percentLabel(visible[index].maturity),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
