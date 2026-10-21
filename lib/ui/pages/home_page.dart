import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../subject_style.dart';
import '../widgets/common.dart';
import 'settings_page.dart';
import 'subject_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyStore>();
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 24, 18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study',
                        style: TextStyle(
                          fontSize: 19,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '学习计划',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _openSettings(context, store),
                    tooltip: '设置',
                    icon: const Icon(Icons.settings_outlined, size: 20),
                  ),
                ],
              ),
            ),
            Divider(color: palette.border),
            Expanded(
              child: PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择学科',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '一次专注一个学科。进入学科后，其他学科不会出现在界面里。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 26),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1040
                            ? 3
                            : constraints.maxWidth >= 660
                            ? 2
                            : 1;
                        const spacing = 18.0;
                        final width =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final subject in Subject.values)
                              SizedBox(
                                width: width,
                                height: 196,
                                child: _SubjectCard(
                                  subject: subject,
                                  plan: store.planFor(subject),
                                  onOpen: () =>
                                      _openSubject(context, store, subject),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '切换学科需要先退出当前学科。',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
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

  void _openSubject(BuildContext context, StudyStore store, Subject subject) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubjectPage(store: store, subject: subject),
      ),
    );
  }

  void _openSettings(BuildContext context, StudyStore store) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(store: store)));
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.plan,
    required this.onOpen,
  });

  final Subject subject;
  final SubjectPlan plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final accent = subjectColor(subject, Theme.of(context).brightness);
    return SurfaceCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(subjectIcon(subject), size: 21, color: accent),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 17,
                color: palette.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subject.label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            plan.total == 0
                ? '还没有知识点'
                : '${plan.total} 个知识点 · ${plan.remainingNew} 个未学',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
          ),
          const Spacer(),
          if (plan.total > 0) ...[
            ProgressBar(value: plan.progress, height: 5),
            const SizedBox(height: 8),
            Text(
              plan.dueCount == 0 ? '今天没有到期复习' : '${plan.dueCount} 个知识点待复习',
              style: TextStyle(
                fontSize: 10.5,
                color: plan.dueCount == 0
                    ? palette.textSecondary
                    : palette.accent,
              ),
            ),
          ] else
            Text(
              '进入后添加学习内容',
              style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
            ),
        ],
      ),
    );
  }
}
