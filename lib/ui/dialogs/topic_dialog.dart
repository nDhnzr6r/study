import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/models.dart';

class TopicDraft {
  const TopicDraft(this.chapter, this.title);

  final String chapter;
  final String title;
}

Future<TopicDraft?> showTopicDialog(
  BuildContext context, {
  required Subject subject,
  required List<String> chapters,
  Topic? topic,
}) {
  return showDialog<TopicDraft>(
    context: context,
    builder: (dialogContext) =>
        _TopicDialog(subject: subject, chapters: chapters, topic: topic),
  );
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog({
    required this.subject,
    required this.chapters,
    this.topic,
  });

  final Subject subject;
  final List<String> chapters;
  final Topic? topic;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final TextEditingController _chapterController = TextEditingController(
    text: widget.topic?.chapter ?? '',
  );
  late final TextEditingController _titleController = TextEditingController(
    text: widget.topic?.title ?? '',
  );
  String? _chapterError;
  String? _titleError;

  @override
  void dispose() {
    _chapterController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final chapter = _chapterController.text.trim();
    final title = _titleController.text.trim();
    if (chapter.isEmpty || title.isEmpty) {
      setState(() {
        _chapterError = chapter.isEmpty ? '请填写章节' : null;
        _titleError = title.isEmpty ? '请填写知识点名称' : null;
      });
      return;
    }
    Navigator.of(context).pop(TopicDraft(chapter, title));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.topic == null ? '添加知识点' : '编辑知识点')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.subject.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette.primary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _chapterController,
                autofocus: widget.topic == null,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '章节',
                  hintText: '例如：第一章 集合与函数',
                  errorText: _chapterError,
                ),
              ),
              if (widget.chapters.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chapter in widget.chapters)
                      ActionChip(
                        label: Text(chapter),
                        onPressed: () {
                          _chapterController.text = chapter;
                          setState(() => _chapterError = null);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: '知识点',
                  hintText: '要学习和复习的内容',
                  errorText: _titleError,
                  alignLabelWithHint: true,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 10),
              Text(
                '同一章节的知识点会排在一起，按添加顺序出现。',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
