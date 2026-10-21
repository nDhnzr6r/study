import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../state/study_store.dart';
import '../pages/decks_page.dart';
import '../pages/overview_page.dart';
import '../pages/review_page.dart';
import '../pages/settings_page.dart';
import '../pages/stats_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyStore>();
    if (store.sessionActive) {
      return ReviewPage(store: store);
    }
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1040;
          return Row(
            children: [
              _Sidebar(
                compact: compact,
                selectedIndex: _index,
                dueCount: store.dueCount,
                onSelect: (index) => setState(() => _index = index),
              ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    OverviewPage(
                      store: store,
                      onOpenDecks: () => setState(() => _index = 1),
                    ),
                    DecksPage(store: store),
                    StatsPage(store: store),
                    SettingsPage(store: store),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.selectedIndex,
    required this.dueCount,
    required this.onSelect,
  });

  final bool compact;
  final int selectedIndex;
  final int dueCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Container(
      width: compact ? 86 : 232,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 22 : 22,
                26,
                compact ? 22 : 22,
                28,
              ),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
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
                      color: onPrimary,
                    ),
                  ),
                  if (!compact) ...[
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
                          '间隔复习',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _NavItem(
              compact: compact,
              icon: Icons.today_rounded,
              label: '今日',
              selected: selectedIndex == 0,
              badge: dueCount,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              compact: compact,
              icon: Icons.style_rounded,
              label: '卡片库',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            _NavItem(
              compact: compact,
              icon: Icons.query_stats_rounded,
              label: '统计',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
            _NavItem(
              compact: compact,
              icon: Icons.tune_rounded,
              label: '设置',
              selected: selectedIndex == 3,
              onTap: () => onSelect(3),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 20,
                14,
                compact ? 12 : 20,
                20,
              ),
              child: Container(
                padding: EdgeInsets.all(compact ? 12 : 14),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: compact
                    ? Tooltip(
                        message: '数据保存在本机',
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: palette.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '数据保存在本机',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '版本 0.1.0',
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.textSecondary.withValues(
                                alpha: 0.75,
                              ),
                            ),
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
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.compact,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final bool compact;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final color = selected ? palette.primary : palette.textSecondary;
    final content = Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 20, color: color),
            if (compact && badge > 0)
              Positioned(
                right: -4,
                top: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? palette.primary : palette.textPrimary,
              ),
            ),
          ),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
            ),
        ],
      ],
    );
    final item = Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: 3),
      child: Material(
        color: selected ? palette.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: palette.primarySoft.withValues(alpha: 0.55),
          child: Container(
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
            child: content,
          ),
        ),
      ),
    );
    if (!compact) return item;
    return Tooltip(message: label, child: item);
  }
}
