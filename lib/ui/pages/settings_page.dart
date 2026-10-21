import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../state/study_store.dart';
import '../dialogs/confirm.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});

  final StudyStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _clearProgress() async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '清空学习进度',
      message: '所有已学记录和复习记录都会被删除，知识点会保留。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await widget.store.clearProgress();
      _showMessage('学习进度已清空');
    } catch (error) {
      _showMessage('清空失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.store.databasePath));
    _showMessage('已复制数据文件路径');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyStore>();
    final palette = AppColors.of(context);
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
                    '设置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionCard(
                      title: '外观',
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '主题跟随系统，或固定为浅色、深色。',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('跟随系统'),
                                icon: Icon(
                                  Icons.brightness_auto_outlined,
                                  size: 16,
                                ),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('浅色'),
                                icon: Icon(Icons.light_mode_outlined, size: 16),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('深色'),
                                icon: Icon(Icons.dark_mode_outlined, size: 16),
                              ),
                            ],
                            selected: {store.themeMode},
                            onSelectionChanged: (selection) {
                              unawaited(store.updateThemeMode(selection.first));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      title: '学习数据',
                      subtitle: '知识点由你自行添加，学习记录保存在本机。',
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 17,
                                color: palette.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '数据文件',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      store.databasePath,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.5,
                                        fontFamily: 'Consolas',
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _copyPath,
                                tooltip: '复制路径',
                                icon: const Icon(Icons.copy_rounded, size: 16),
                              ),
                            ],
                          ),
                          Divider(color: palette.border, height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '清空学习进度',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '删除全部已学记录和复习记录，保留知识点。',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.5,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              TextButton(
                                onPressed: _busy ? null : _clearProgress,
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.danger,
                                ),
                                child: const Text('清空'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      title: '关于',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: palette.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  size: 21,
                                  color: palette.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Study',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '版本 0.3.0',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '六学科学习计划应用。每个学科的知识点由使用者自行添加，学习后按固定节奏安排复习。',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.7,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '复习节奏：学后 1、3、7、15、30 天各复习一次。',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.7,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '源代码以 GNU General Public License v3.0 发布。',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.7,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
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
