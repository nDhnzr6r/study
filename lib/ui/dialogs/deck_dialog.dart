import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/models.dart';

class DeckDraft {
  const DeckDraft(this.name, this.description);

  final String name;
  final String description;
}

Future<DeckDraft?> showDeckDialog(BuildContext context, {Deck? deck}) {
  return showDialog<DeckDraft>(
    context: context,
    builder: (dialogContext) => _DeckDialog(deck: deck),
  );
}

class _DeckDialog extends StatefulWidget {
  const _DeckDialog({this.deck});

  final Deck? deck;

  @override
  State<_DeckDialog> createState() => _DeckDialogState();
}

class _DeckDialogState extends State<_DeckDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.deck?.name ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.deck?.description ?? '');
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写卡组名称');
      return;
    }
    Navigator.of(
      context,
    ).pop(DeckDraft(name, _descriptionController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return AlertDialog(
      title: Text(widget.deck == null ? '新建卡组' : '编辑卡组'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '卡组名称',
                hintText: '例如：线性代数',
                errorText: _error,
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              maxLength: 120,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '说明（可选）',
                hintText: '这一组卡片准备学什么',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '一个卡组可以装下一类知识点，复习时会一起出现。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: palette.textSecondary,
              ),
            ),
          ],
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
