import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../domain/scheduler.dart';
import '../../state/study_store.dart';
import '../widgets/common.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.store});

  final StudyStore store;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'review');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _exit() {
    unawaited(widget.store.closeSession());
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final store = widget.store;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _exit();
      return KeyEventResult.handled;
    }
    if (store.sessionFinished) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        _exit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      store.revealAnswer();
      return KeyEventResult.handled;
    }
    if (store.sessionAnswerShown) {
      final rating = _ratingForKey(event.logicalKey);
      if (rating != null) {
        unawaited(store.rate(rating));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Rating? _ratingForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      return Rating.again;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      return Rating.hard;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      return Rating.good;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      return Rating.easy;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final palette = AppColors.of(context);
    final card = store.currentCard;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 28, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _exit,
                      tooltip: '退出复习（Esc）',
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '复习',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          store.sessionScopeName,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      store.sessionFinished
                          ? '已完成'
                          : '${store.sessionPosition} / ${store.sessionTotal}',
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
                child: ProgressBar(value: store.sessionProgress, height: 5),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 26, 28, 38),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 64)
                                .clamp(0.0, double.infinity)
                                .toDouble(),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: store.sessionFinished || card == null
                                  ? _SessionSummary(store: store)
                                  : _ReviewBody(store: store, card: card),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.store, required this.card});

  final StudyStore store;
  final StudyCard card;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final stateColor = switch (card.state) {
      CardState.newCard => palette.info,
      CardState.learning => palette.warning,
      CardState.review => palette.primary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(38),
          onTap: store.sessionAnswerShown ? null : store.revealAnswer,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: card.state.label,
                      color: stateColor,
                      icon: card.state == CardState.review
                          ? Icons.autorenew_rounded
                          : Icons.school_outlined,
                      dense: true,
                    ),
                    const Spacer(),
                    Text(
                      card.reps == 0 ? '第一次学习' : '已复习 ${card.reps} 次',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  '正面',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  card.front,
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                ),
                if (store.sessionAnswerShown) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Divider(color: palette.border),
                  ),
                  Text(
                    '背面',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    card.back,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.7,
                      color: palette.textPrimary,
                    ),
                  ),
                  if (card.note.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 16,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              card.note,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.7,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 44),
                  Center(
                    child: FilledButton.icon(
                      onPressed: store.revealAnswer,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('显示答案'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '点击卡片或按空格键',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (store.sessionAnswerShown) ...[
          const SizedBox(height: 20),
          _RatingBar(store: store, card: card),
        ],
      ],
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.store, required this.card});

  final StudyStore store;
  final StudyCard card;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final ratings = [Rating.again, Rating.hard, Rating.good, Rating.easy];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '这次记得怎么样？',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '按数字键 1 – 4 选择',
              style: TextStyle(fontSize: 11, color: palette.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var index = 0; index < ratings.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: _RatingButton(
                  rating: ratings[index],
                  card: card,
                  onPressed: () => store.rate(ratings[index]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.card,
    required this.onPressed,
  });

  final Rating rating;
  final StudyCard card;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final tone = switch (rating) {
      Rating.again => palette.danger,
      Rating.hard => palette.warning,
      Rating.good => palette.success,
      Rating.easy => palette.info,
    };
    final preview = Scheduler.schedule(card, rating, DateTime.now());
    return Material(
      color: tone.withValues(alpha: 0.09),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tone.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: tone.withValues(alpha: 0.16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 17,
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${rating.value + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tone,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    rating.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                intervalLabel(preview.intervalDays),
                style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.store});

  final StudyStore store;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final reviewed = store.sessionReviewed;
    final again = store.sessionAgain;
    final kept = reviewed == 0 ? 1.0 : (reviewed - again) / reviewed;
    final canContinue = store.dueCount > 0 || store.newAvailable > 0;
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
            '本轮复习完成',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '完成 $reviewed 次复习 · 用时 ${_durationLabel(store.sessionDuration)}',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(label: '复习次数', value: '$reviewed'),
              ),
              Container(width: 1, height: 38, color: palette.border),
              Expanded(
                child: _SummaryStat(label: '需要加强', value: '$again'),
              ),
              Container(width: 1, height: 38, color: palette.border),
              Expanded(
                child: _SummaryStat(label: '保持率', value: percentLabel(kept)),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (canContinue) ...[
                OutlinedButton(
                  onPressed: () async {
                    await store.closeSession();
                    await store.startSession();
                  },
                  child: const Text('再复习一轮'),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton(
                onPressed: store.closeSession,
                child: const Text('回到今日'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _durationLabel(Duration duration) {
    if (duration.inMinutes < 1) return '不到 1 分钟';
    return '${duration.inMinutes} 分钟';
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: palette.textSecondary),
        ),
      ],
    );
  }
}
