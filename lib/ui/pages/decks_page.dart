import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../dialogs/card_dialog.dart';
import '../dialogs/confirm_dialog.dart';
import '../dialogs/deck_dialog.dart';
import '../widgets/common.dart';

class DecksPage extends StatefulWidget {
  const DecksPage({super.key, required this.store});

  final StudyStore store;

  @override
  State<DecksPage> createState() => _DecksPageState();
}

class _DecksPageState extends State<DecksPage> {
  int? _selectedDeckId;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  CardFilter _filter = CardFilter.all;
  List<StudyCard> _cards = const [];
  bool _loadingCards = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openDeck(int deckId) {
    setState(() {
      _selectedDeckId = deckId;
      _cards = const [];
      _filter = CardFilter.all;
      _searchController.clear();
    });
    _loadCards();
  }

  void _backToList() {
    setState(() {
      _selectedDeckId = null;
      _cards = const [];
      _filter = CardFilter.all;
      _searchController.clear();
    });
  }

  Future<void> _loadCards() async {
    final deckId = _selectedDeckId;
    if (deckId == null) return;
    setState(() => _loadingCards = true);
    final cards = await widget.store.cardsInDeck(
      deckId,
      query: _searchController.text,
      filter: _filter,
    );
    if (!mounted || _selectedDeckId != deckId) return;
    setState(() {
      _cards = cards;
      _loadingCards = false;
    });
  }

  Future<void> _createDeck() async {
    final draft = await showDeckDialog(context);
    if (draft == null) return;
    await widget.store.createDeck(draft.name, draft.description);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已创建卡组「${draft.name}」')));
  }

  Future<void> _editDeck(Deck deck) async {
    final draft = await showDeckDialog(context, deck: deck);
    if (draft == null || deck.id == null) return;
    await widget.store.updateDeck(deck.id!, draft.name, draft.description);
  }

  Future<void> _deleteDeck(DeckSummary summary) async {
    final deck = summary.deck;
    if (deck.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '删除卡组',
      message: '「${deck.name}」中的 ${summary.total} 张卡片和复习记录都会被删除。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    await widget.store.deleteDeck(deck.id!);
    if (!mounted) return;
    if (_selectedDeckId == deck.id) {
      _backToList();
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除卡组「${deck.name}」')));
  }

  Future<void> _addCard(DeckSummary summary) async {
    final deck = summary.deck;
    if (deck.id == null) return;
    final draft = await showCardDialog(context, deckName: deck.name);
    if (draft == null) return;
    await widget.store.createCard(
      deckId: deck.id!,
      front: draft.front,
      back: draft.back,
      note: draft.note,
    );
    if (!mounted) return;
    await _loadCards();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('卡片已添加')));
  }

  Future<void> _editCard(DeckSummary summary, StudyCard card) async {
    final draft = await showCardDialog(
      context,
      deckName: summary.deck.name,
      card: card,
    );
    if (draft == null || card.id == null) return;
    await widget.store.updateCard(
      cardId: card.id!,
      front: draft.front,
      back: draft.back,
      note: draft.note,
    );
    if (!mounted) return;
    await _loadCards();
  }

  Future<void> _deleteCard(StudyCard card) async {
    if (card.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '删除卡片',
      message: '这张卡片和它的复习记录都会被删除。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    await widget.store.deleteCard(card.id!);
    if (!mounted) return;
    await _loadCards();
  }

  Future<void> _startDeck(DeckSummary summary) async {
    if (summary.deck.id == null) return;
    final started = await widget.store.startSession(deckId: summary.deck.id);
    if (!mounted || started) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('这个卡组今天没有需要学习的卡片')));
  }

  @override
  Widget build(BuildContext context) {
    final summary = _selectedDeckId == null
        ? null
        : widget.store.summaryFor(_selectedDeckId!);
    if (summary != null) {
      return _buildDetail(context, summary);
    }
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final decks = widget.store.decks;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: '卡片库',
            subtitle: '按卡组整理学习内容，每天抽取到期卡片复习。',
            actions: [
              FilledButton.icon(
                onPressed: _createDeck,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建卡组'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (decks.isEmpty)
            SurfaceCard(
              child: EmptyState(
                icon: Icons.layers_outlined,
                title: '还没有卡组',
                message: '先为一类知识建立卡组，再往里面添加卡片。',
                actionLabel: '新建卡组',
                onAction: _createDeck,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1020
                    ? 3
                    : constraints.maxWidth >= 660
                    ? 2
                    : 1;
                const spacing = 18.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final summary in decks)
                      SizedBox(
                        width: width,
                        height: 222,
                        child: _DeckCard(
                          summary: summary,
                          onOpen: () => _openDeck(summary.deck.id!),
                          onEdit: () => _editDeck(summary.deck),
                          onDelete: () => _deleteDeck(summary),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context, DeckSummary summary) {
    final palette = AppColors.of(context);
    final deck = summary.deck;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: _backToList,
                tooltip: '返回卡片库',
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (deck.description.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        deck.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'edit') _editDeck(deck);
                  if (value == 'delete') _deleteDeck(summary);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 17),
                        SizedBox(width: 10),
                        Text('编辑卡组'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 17),
                        SizedBox(width: 10),
                        Text('删除卡组'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: summary.available > 0
                    ? () => _startDeck(summary)
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('复习此卡组'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _addCard(summary),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加卡片'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) {
                    setState(() {});
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 220),
                      _loadCards,
                    );
                  },
                  decoration: InputDecoration(
                    hintText: '搜索正面、背面或备注',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _loadCards();
                            },
                            icon: const Icon(Icons.close_rounded, size: 16),
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              for (final filter in CardFilter.values)
                ChoiceChip(
                  label: Text(filter.label),
                  selected: _filter == filter,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _filter = filter);
                    _loadCards();
                  },
                ),
              Text(
                '${_cards.length} 张',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loadingCards && _cards.isEmpty)
            const SurfaceCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_cards.isEmpty)
            SurfaceCard(child: _cardsEmptyState(context))
          else
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < _cards.length; index++) ...[
                    if (index > 0)
                      Divider(
                        color: palette.border.withValues(alpha: 0.75),
                        height: 1,
                      ),
                    _CardRow(
                      card: _cards[index],
                      onEdit: () => _editCard(summary, _cards[index]),
                      onDelete: () => _deleteCard(_cards[index]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardsEmptyState(BuildContext context) {
    if (_searchController.text.trim().isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: '没有找到卡片',
        message: '换个关键词，或切换筛选条件。',
        actionLabel: '清除搜索',
        actionIcon: Icons.close_rounded,
        onAction: () {
          _searchController.clear();
          setState(() {});
          _loadCards();
        },
      );
    }
    if (_filter != CardFilter.all) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: '这个筛选下没有卡片',
        message: '切换到「全部」查看其他卡片。',
        actionLabel: '查看全部',
        actionIcon: Icons.filter_alt_outlined,
        onAction: () {
          setState(() => _filter = CardFilter.all);
          _loadCards();
        },
      );
    }
    return EmptyState(
      icon: Icons.note_add_outlined,
      title: '还没有卡片',
      message: '把问题写在正面，答案写在背面。',
      actionLabel: '添加第一张卡片',
      onAction: () {
        final summary = _selectedDeckId == null
            ? null
            : widget.store.summaryFor(_selectedDeckId!);
        if (summary != null) _addCard(summary);
      },
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.summary,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final DeckSummary summary;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final deck = summary.deck;
    return SurfaceCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.layers_rounded,
                  size: 19,
                  color: palette.primary,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: '卡组操作',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 19,
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
                        Text('编辑卡组'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 17),
                        SizedBox(width: 10),
                        Text('删除卡组'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deck.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            deck.description.isEmpty ? '暂无说明' : deck.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: deck.description.isEmpty
                  ? palette.textSecondary.withValues(alpha: 0.65)
                  : palette.textSecondary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _DeckStat(
                label: '待复习',
                value: '${summary.due}',
                color: summary.due > 0 ? palette.danger : palette.textSecondary,
              ),
              const SizedBox(width: 16),
              _DeckStat(
                label: '新卡',
                value: '${summary.newCount}',
                color: summary.newCount > 0
                    ? palette.primary
                    : palette.textSecondary,
              ),
              const Spacer(),
              Text(
                '${summary.total} 张',
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ProgressBar(value: summary.maturity, height: 5)),
              const SizedBox(width: 8),
              Text(
                percentLabel(summary.maturity),
                style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeckStat extends StatelessWidget {
  const _DeckStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final now = DateTime.now();
    final statusColor = switch (card.state) {
      CardState.newCard => palette.textSecondary,
      CardState.learning => palette.warning,
      CardState.review =>
        card.isDue(now)
            ? (card.dueDate != null && card.dueDate!.isBefore(dateOnly(now))
                  ? palette.danger
                  : palette.primary)
            : palette.textSecondary,
    };
    final statusText = card.state == CardState.newCard
        ? '新卡'
        : dueLabel(card.dueDate, now);
    final subText = card.state == CardState.newCard
        ? '尚未学习'
        : (card.intervalDays == 0
              ? card.state.label
              : '间隔 ${card.intervalDays} 天');

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
                      card.front,
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
                      card.back,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subText,
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: '卡片操作',
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
