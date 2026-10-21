import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../dialogs/confirm.dart';
import '../dialogs/topic_dialog.dart';
import '../widgets/common.dart';

class TopicManagerPage extends StatelessWidget {
  const TopicManagerPage({
    super.key,
    required this.store,
    required this.subject,
  });

  final StudyStore store;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final plan = context.watch<StudyStore>().planFor(subject);
    final chapters = <String, List<TopicStatus>>{};
    for (final status in plan.topics) {
      chapters.putIfAbsent(status.topic.chapter, () => []).add(status);
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '知识点 · ${subject.label}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _addTopic(context, plan),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('添加知识点'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageBody(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: plan.topics.isEmpty
                      ? _emptyState(context, plan)
                      : _topicList(context, chapters, plan),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, SubjectPlan plan) {
    return SurfaceCard(
      child: EmptyState(
        icon: Icons.playlist_add_rounded,
        title: '还没有知识点',
        message: '把要学习的章节和知识点加进来，之后就可以按计划学习和复习。',
        actionLabel: '添加第一个知识点',
        onAction: () => _addTopic(context, plan),
      ),
    );
  }

  Widget _topicList(
    BuildContext context,
    Map<String, List<TopicStatus>> chapters,
    SubjectPlan plan,
  ) {
    final palette = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '知识点',
          style: TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '共 ${plan.total} 个知识点，${plan.chapters.length} 个章节。',
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        const SizedBox(height: 24),
        for (final entry in chapters.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 9, top: 4),
            child: Row(
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.length} 个',
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < entry.value.length; index++) ...[
                  if (index > 0) Divider(color: palette.border, height: 1),
                  _TopicRow(
                    status: entry.value[index],
                    onEdit: () =>
                        _editTopic(context, entry.value[index].topic, plan),
                    onDelete: () => _deleteTopic(context, entry.value[index]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Future<void> _addTopic(BuildContext context, SubjectPlan plan) async {
    final draft = await showTopicDialog(
      context,
      subject: subject,
      chapters: plan.chapters.map((chapter) => chapter.name).toList(),
    );
    if (draft == null) return;
    await store.createTopic(
      subject: subject,
      chapter: draft.chapter,
      title: draft.title,
    );
  }

  Future<void> _editTopic(
    BuildContext context,
    Topic topic,
    SubjectPlan plan,
  ) async {
    final draft = await showTopicDialog(
      context,
      subject: subject,
      chapters: plan.chapters.map((chapter) => chapter.name).toList(),
      topic: topic,
    );
    if (draft == null || topic.id == null) return;
    await store.updateTopic(
      topic.id!,
      chapter: draft.chapter,
      title: draft.title,
    );
  }

  Future<void> _deleteTopic(BuildContext context, TopicStatus status) async {
    final id = status.topic.id;
    if (id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '删除知识点',
      message: '删除「${status.topic.title}」后，它的学习与复习记录也会删除。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    await store.deleteTopic(id);
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.status,
    required this.onEdit,
    required this.onDelete,
  });

  final TopicStatus status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final progress = status.progress;
    final subtitle = progress == null
        ? '未学习'
        : status.isCompleted
        ? '已完成'
        : '第 ${status.reviewStage} 次复习 · ${dueLabel(status.nextReviewDate, DateTime.now())}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        hoverColor: palette.primarySoft.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: progress == null
                            ? palette.textSecondary
                            : status.isCompleted
                            ? palette.success
                            : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                tooltip: '知识点操作',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: palette.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 17),
                        SizedBox(width: 10),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 17),
                        SizedBox(width: 10),
                        Text('删除'),
                      ],
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
