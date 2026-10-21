import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/models.dart';

class CardDraft {
  const CardDraft(this.front, this.back, this.note);

  final String front;
  final String back;
  final String note;
}

Future<CardDraft?> showCardDialog(
  BuildContext context, {
  required String deckName,
  StudyCard? card,
}) {
  return showDialog<CardDraft>(
    context: context,
    builder: (dialogContext) => _CardDialog(deckName: deckName, card: card),
  );
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({required this.deckName, this.card});

  final String deckName;
  final StudyCard? card;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final TextEditingController _frontController = TextEditingController(
    text: widget.card?.front ?? '',
  );
  late final TextEditingController _backController = TextEditingController(
    text: widget.card?.back ?? '',
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.card?.note ?? '',
  );
  String? _frontError;
  String? _backError;

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();
    if (front.isEmpty || back.isEmpty) {
      setState(() {
        _frontError = front.isEmpty ? '请填写正面' : null;
        _backError = back.isEmpty ? '请填写背面' : null;
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(CardDraft(front, back, _noteController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.card == null ? '新建卡片' : '编辑卡片')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.deckName,
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
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _frontController,
                autofocus: widget.card == null,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: '正面',
                  hintText: '要记住的问题、概念或提示',
                  errorText: _frontError,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _backController,
                minLines: 4,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: '背面',
                  hintText: '答案与解释',
                  errorText: _backError,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '例子、出处或记忆线索',
                  alignLabelWithHint: true,
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
