import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../dialogs/confirm.dart';
import '../widgets/common.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({
    super.key,
    required this.store,
    required this.subject,
    required this.topics,
  });

  final StudyStore store;
  final Subject subject;
  final List<Topic> topics;

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  final Set<int> _checked = {};
  bool _saving = false;
  bool _completed = false;
  int _savedCount = 0;

  List<Topic> get _selectedTopics => [
    for (final topic in widget.topics)
      if (topic.id != null && _checked.contains(topic.id)) topic,
  ];

  void _toggle(Topic topic) {
    final id = topic.id;
    if (id == null || _saving || _completed) return;
    setState(() {
      if (!_checked.add(id)) _checked.remove(id);
    });
  }

  Future<int> _save() async {
    final count = await widget.store.markLearned(_selectedTopics);
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
      title: '结束学习',
      message: '已勾选的 ${_checked.length} 个知识点会记录为今天学会。',
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
                    tooltip: '退出学习',
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '学习 · ${widget.subject.label}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '今天的新知识点',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${_checked.length} / ${widget.topics.length}',
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
                value: widget.topics.isEmpty
                    ? 0
                    : _checked.length / widget.topics.length,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今天要学的知识点',
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
          '按顺序学习，学完一个就勾选。',
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        const SizedBox(height: 24),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < widget.topics.length; index++) ...[
                if (index > 0) Divider(color: palette.border, height: 1),
                _LearningRow(
                  index: index,
                  topic: widget.topics[index],
                  checked:
                      widget.topics[index].id != null &&
                      _checked.contains(widget.topics[index].id),
                  onTap: () => _toggle(widget.topics[index]),
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
                      '已勾选 ${_checked.length} / ${widget.topics.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '完成后会从明天开始安排第一次复习。',
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
                label: Text(_saving ? '正在保存' : '完成学习'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final palette = AppColors.of(context);
    final dueCount = widget.store.planFor(widget.subject).dueCount;
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
            '今天学了 $_savedCount 个知识点',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '明天开始第 1 次复习，之后是第 3、7、15、30 天。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: palette.textSecondary,
            ),
          ),
          if (dueCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '还有 $dueCount 个知识点到期，先完成今天的复习。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: palette.accent),
            ),
          ],
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dueCount > 0) ...[
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('去复习'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('回到数学'),
                ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('回到数学'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearningRow extends StatelessWidget {
  const _LearningRow({
    required this.index,
    required this.topic,
    required this.checked,
    required this.onTap,
  });

  final int index;
  final Topic topic;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: palette.primarySoft.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: checked ? palette.primarySoft : palette.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: checked ? palette.primary : palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.chapter,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      topic.title,
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
