import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'learning_page.dart';
import 'review_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key, required this.store, required this.subject});

  final StudyStore store;
  final Subject subject;

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  int _newCount = 5;

  @override
  Widget build(BuildContext context) {
    if (!widget.subject.hasContent) {
      return _EmptySubject(subject: widget.subject);
    }
    final plan = widget.store.planFor(widget.subject);
    if (plan.total == 0) {
      return _EmptySubject(subject: widget.subject);
    }
    final remaining = plan.remainingNew;
    final count = remaining == 0 ? 0 : _newCount.clamp(1, remaining).toInt();

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: widget.subject.label,
            subtitle: '学习计划与复习安排',
            actions: [
              StatusPill(
                label: '已学 ${plan.learned} / ${plan.total}',
                color: AppColors.of(context).primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: ProgressBar(value: plan.progress, height: 6)),
              const SizedBox(width: 12),
              Text(
                percentLabel(plan.progress),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final learning = _NewLearningCard(
                plan: plan,
                count: count,
                onMinus: count > 1
                    ? () => setState(() => _newCount = count - 1)
                    : null,
                onPlus: count < remaining
                    ? () => setState(() => _newCount = count + 1)
                    : null,
                onStart: count == 0
                    ? null
                    : () => _startLearning(context, plan, count),
              );
              final review = _ReviewCard(
                plan: plan,
                onStart: plan.dueCount == 0
                    ? null
                    : () => _startReview(context, plan),
              );
              if (!wide) {
                return Column(
                  children: [learning, const SizedBox(height: 20), review],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: learning),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: review),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final chapters = SectionCard(
                title: '章节进度',
                subtitle: '共 ${plan.chapters.length} 个章节',
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < plan.chapters.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Divider(
                          color: AppColors.of(
                            context,
                          ).border.withValues(alpha: 0.7),
                          height: 18,
                        ),
                      _ChapterRow(chapter: plan.chapters[index]),
                    ],
                  ],
                ),
              );
              final forecast = SectionCard(
                title: '未来 7 天',
                subtitle: '每天需要复习的知识点',
                child: Column(
                  children: [
                    DayBarChart(
                      data: plan.forecast,
                      labels: [
                        for (
                          var index = 0;
                          index < plan.forecast.length;
                          index++
                        )
                          index == 0
                              ? '今天'
                              : shortWeekdayLabel(plan.forecast[index].day),
                      ],
                      height: 138,
                    ),
                    const SizedBox(height: 18),
                    Divider(color: AppColors.of(context).border),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniStat(label: '今日新学', value: '${plan.learnedToday}'),
                        _MiniStat(
                          label: '今日复习',
                          value: '${plan.reviewedToday}',
                        ),
                        _MiniStat(label: '连续学习', value: '${plan.streak} 天'),
                      ],
                    ),
                  ],
                ),
              );
              if (!wide) {
                return Column(
                  children: [chapters, const SizedBox(height: 20), forecast],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chapters),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: forecast),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startLearning(
    BuildContext context,
    SubjectPlan plan,
    int count,
  ) async {
    final topics = plan.newTopics.take(count).toList();
    if (topics.isEmpty) return;
    final goToReview = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LearningPage(
          store: widget.store,
          subject: widget.subject,
          topics: topics,
        ),
      ),
    );
    if (goToReview == true && context.mounted) {
      final latest = widget.store.planFor(widget.subject);
      if (latest.dueTopics.isNotEmpty) {
        await _startReview(context, latest);
      }
    }
  }

  Future<void> _startReview(BuildContext context, SubjectPlan plan) async {
    if (plan.dueTopics.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          store: widget.store,
          subject: widget.subject,
          items: List.of(plan.dueTopics),
        ),
      ),
    );
  }
}

class _NewLearningCard extends StatelessWidget {
  const _NewLearningCard({
    required this.plan,
    required this.count,
    required this.onMinus,
    required this.onPlus,
    required this.onStart,
  });

  final SubjectPlan plan;
  final int count;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final preview = plan.newTopics.take(count > 4 ? 4 : count).toList();
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primarySoft, palette.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: palette.primary,
              ),
              const SizedBox(width: 7),
              Text(
                '学新的',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: palette.primary,
                ),
              ),
              const Spacer(),
              if (plan.remainingNew == 0)
                StatusPill(
                  label: '已全部学完',
                  color: palette.success,
                  icon: Icons.check_rounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${plan.remainingNew}',
                style: TextStyle(
                  fontSize: 50,
                  height: 0.95,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '个知识点未学',
                  style: TextStyle(fontSize: 14, color: palette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '今天学几个由你决定，学完再从第一个开始安排复习。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: palette.textSecondary,
            ),
          ),
          if (plan.remainingNew > 0) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '今天学',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                _CountStepper(count: count, onMinus: onMinus, onPlus: onPlus),
                const SizedBox(width: 10),
                Text(
                  '个',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: palette.border.withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            Text(
              '接下来',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.6,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final topic in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 86,
                      child: Text(
                        topic.chapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        topic.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (count > preview.length)
              Text(
                '另有 ${count - preview.length} 个',
                style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
              ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 19),
              label: const Text('开始学习'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.count,
    required this.onMinus,
    required this.onPlus,
  });

  final int count;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            tooltip: '减少',
            icon: const Icon(Icons.remove_rounded, size: 16),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            tooltip: '增加',
            icon: const Icon(Icons.add_rounded, size: 16),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.plan, required this.onStart});

  final SubjectPlan plan;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final stages = plan.dueByStage.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.autorenew_rounded, size: 16, color: palette.accent),
              const SizedBox(width: 7),
              Text(
                '复习',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: palette.accent,
                ),
              ),
              const Spacer(),
              if (plan.dueCount > 0)
                StatusPill(
                  label: '${plan.dueCount} 个到期',
                  color: palette.accent,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${plan.dueCount}',
                style: TextStyle(
                  fontSize: 50,
                  height: 0.95,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '个知识点到期',
                  style: TextStyle(fontSize: 14, color: palette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stages.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final stage in stages)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '第 ${stage.key} 次 · ${stage.value} 个',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '复习完成后勾选，系统会安排下一次复习。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: palette.textSecondary,
              ),
            ),
          ] else ...[
            Text(
              '今天没有到期的复习。',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '新学的知识点会在明天出现第一次复习。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 22),
          Divider(color: palette.border),
          const SizedBox(height: 14),
          Text(
            '复习节奏：学后 1、3、7、15、30 天',
            style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: plan.dueCount == 0
                ? OutlinedButton(onPressed: null, child: const Text('暂无复习'))
                : FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 19),
                    label: const Text('开始复习'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.chapter});

  final ChapterPlan chapter;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      chapter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (chapter.due > 0) ...[
                    const SizedBox(width: 8),
                    StatusPill(
                      label: '${chapter.due} 待复习',
                      color: palette.accent,
                      dense: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${chapter.learned}/${chapter.total} 已学 · ${chapter.completed} 已完成',
                style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 92,
          child: ProgressBar(value: chapter.progress, height: 6),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            percentLabel(chapter.progress),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

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
          style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EmptySubject extends StatelessWidget {
  const _EmptySubject({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: subject.label, subtitle: '内容准备中'),
          const SizedBox(height: 26),
          SurfaceCard(
            child: EmptyState(
              icon: _iconFor(subject),
              title: '${subject.label}计划尚未开放',
              message: '当前版本先开放数学，其余学科会陆续加入。',
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(Subject subject) => switch (subject) {
    Subject.chinese => Icons.menu_book_rounded,
    Subject.math => Icons.functions_rounded,
    Subject.english => Icons.translate_rounded,
    Subject.physics => Icons.bolt_rounded,
    Subject.chemistry => Icons.science_rounded,
    Subject.biology => Icons.eco_rounded,
  };
}
