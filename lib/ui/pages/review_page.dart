import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../dialogs/confirm.dart';
import '../widgets/common.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.store,
    required this.subject,
    required this.items,
  });

  final StudyStore store;
  final Subject subject;
  final List<TopicStatus> items;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final Set<int> _checked = {};
  bool _saving = false;
  bool _completed = false;
  int _savedCount = 0;

  List<TopicStatus> get _selectedItems => [
    for (final status in widget.items)
      if (status.topic.id != null && _checked.contains(status.topic.id)) status,
  ];

  void _toggle(TopicStatus status) {
    final id = status.topic.id;
    if (id == null || _saving || _completed) return;
    setState(() {
      if (!_checked.add(id)) _checked.remove(id);
    });
  }

  Future<int> _save() async {
    final count = await widget.store.markReviewed(_selectedItems);
    return count;
  }

  Future<void> _complete() async {
    if (_saving || _checked.isEmpty) return;
    setState(() => _saving = true);
    final count = await _save();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _completed = true;
      _savedCount = count;
    });
  }

  Future<void> _close() async {
    if (_completed || _checked.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '结束复习',
      message: '已勾选的 ${_checked.length} 个知识点会记录为今天完成复习。',
      confirmLabel: '结束并保存',
    );
    if (!confirmed || !mounted) return;
    await _save();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 28, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _saving ? null : _close,
                    tooltip: '退出复习',
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '复习 · ${widget.subject.label}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '到期的知识点',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${_checked.length} / ${widget.items.length}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ProgressBar(
                value: widget.items.isEmpty
                    ? 0
                    : _checked.length / widget.items.length,
                height: 5,
              ),
            ),
            Expanded(
              child: PageBody(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _completed
                      ? _buildSummary(context)
                      : _buildList(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final palette = AppColors.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今天要复习的知识点',
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
          '复习完成后勾选，系统会安排下一次复习。',
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        const SizedBox(height: 24),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < widget.items.length; index++) ...[
                if (index > 0) Divider(color: palette.border, height: 1),
                _ReviewRow(
                  status: widget.items[index],
                  now: now,
                  checked:
                      widget.items[index].topic.id != null &&
                      _checked.contains(widget.items[index].topic.id),
                  onTap: () => _toggle(widget.items[index]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已勾选 ${_checked.length} / ${widget.items.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '剩余的复习会继续留在今天的列表里。',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: _checked.isEmpty || _saving ? null : _complete,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? '正在保存' : '完成复习'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final palette = AppColors.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 46),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 34, color: palette.primary),
          ),
          const SizedBox(height: 24),
          Text(
            '完成 $_savedCount 个知识点的复习',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '下一次复习已经按 1、3、7、15、30 天的节奏排好。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('回到数学'),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.status,
    required this.now,
    required this.checked,
    required this.onTap,
  });

  final TopicStatus status;
  final DateTime now;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final due = status.nextReviewDate;
    final overdue = due != null && due.isBefore(dateOnly(now));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: palette.primarySoft.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.topic.chapter,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status.topic.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: checked
                            ? palette.textSecondary
                            : palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    label: '第 ${status.reviewStage} 次复习',
                    color: palette.primary,
                    dense: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overdue
                        ? '逾期 ${dateOnly(now).difference(due).inDays} 天'
                        : '今天',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: overdue ? palette.danger : palette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                activeColor: palette.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
