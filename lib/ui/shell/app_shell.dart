import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../data/models.dart';
import '../../state/study_store.dart';
import '../pages/settings_page.dart';
import '../pages/subject_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyStore>();
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1080;
          return Row(
            children: [
              _Sidebar(
                compact: compact,
                selectedIndex: _index,
                dueCount: store.mathDueCount,
                onSelect: (index) => setState(() => _index = index),
              ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (final subject in Subject.values)
                      SubjectPage(store: store, subject: subject),
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
              padding: EdgeInsets.fromLTRB(22, 26, 22, 24),
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
                          '学习计划',
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
            for (var index = 0; index < Subject.values.length; index++)
              _NavItem(
                compact: compact,
                icon: _subjectIcon(Subject.values[index]),
                label: Subject.values[index].label,
                selected: selectedIndex == index,
                badge: Subject.values[index] == Subject.math ? dueCount : 0,
                onTap: () => onSelect(index),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Divider(color: palette.border),
            ),
            _NavItem(
              compact: compact,
              icon: Icons.tune_rounded,
              label: '设置',
              selected: selectedIndex == 6,
              onTap: () => onSelect(6),
            ),
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
                            '版本 0.2.0',
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

  static IconData _subjectIcon(Subject subject) => switch (subject) {
    Subject.chinese => Icons.menu_book_rounded,
    Subject.math => Icons.functions_rounded,
    Subject.english => Icons.translate_rounded,
    Subject.physics => Icons.bolt_rounded,
    Subject.chemistry => Icons.science_rounded,
    Subject.biology => Icons.eco_rounded,
  };
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
