import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../services/file_dialog.dart';
import '../../state/study_store.dart';
import '../dialogs/confirm_dialog.dart';
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

  Future<void> _export() async {
    if (_busy) return;
    final path = showSaveJsonDialog(
      suggestedName: 'study-${dateKey(DateTime.now())}.json',
    );
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final data = await widget.store.exportJson();
      await File(path).writeAsString(data, flush: true);
      _showMessage('已导出到 $path');
    } catch (error) {
      _showMessage('导出失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final path = showOpenJsonDialog();
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final content = await File(path).readAsString();
      if (!mounted) return;
      final confirmed = await showConfirmDialog(
        context,
        title: '导入学习内容',
        message: '导入会替换当前全部卡组、卡片与复习记录，并保留设置。',
        confirmLabel: '导入',
        destructive: true,
      );
      if (!confirmed) return;
      await widget.store.importJson(content);
      if (!mounted) return;
      _showMessage('已导入 ${widget.store.totalCards} 张卡片');
    } on FormatException catch (error) {
      _showMessage('导入失败：${error.message}');
    } catch (error) {
      _showMessage('导入失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '清空学习数据',
      message: '全部卡组、卡片与复习记录都会被删除，设置会保留。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await widget.store.clearAll();
      _showMessage('学习数据已清空');
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
    final store = widget.store;
    final palette = AppColors.of(context);
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '设置', subtitle: '调整每天的节奏，以及数据保存的位置。'),
          const SizedBox(height: 26),
          SectionCard(
            title: '学习计划',
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '每日新卡上限',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '每天最多引入多少张新卡片。设为 0 时只复习到期内容。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _Stepper(
                  value: store.dailyNewLimit,
                  onChanged: (value) =>
                      unawaited(store.updateDailyNewLimit(value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                      icon: Icon(Icons.brightness_auto_outlined, size: 16),
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
            title: '数据',
            subtitle: '学习内容保存在本机，可以导出为 JSON 文件备份或迁移。',
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.file_download_outlined,
                  title: '导出学习内容',
                  description: '把全部卡组与卡片保存为一个 JSON 文件。',
                  action: OutlinedButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('导出'),
                  ),
                ),
                Divider(color: palette.border, height: 1),
                _DataRow(
                  icon: Icons.file_upload_outlined,
                  title: '导入学习内容',
                  description: '用备份文件替换当前的卡组、卡片与复习记录。',
                  action: OutlinedButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.upload_rounded, size: 17),
                    label: const Text('导入'),
                  ),
                ),
                Divider(color: palette.border, height: 1),
                _DataRow(
                  icon: Icons.delete_outline_rounded,
                  title: '清空学习数据',
                  description: '删除全部卡组、卡片与复习记录。',
                  action: TextButton(
                    onPressed: _busy ? null : _clear,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.danger,
                    ),
                    child: const Text('清空'),
                  ),
                ),
                Divider(color: palette.border, height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
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
                          '版本 0.1.0',
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
                  'Windows 端的本地间隔复习工具，使用 Flutter 构建。复习间隔根据每次评分调整：忘记的卡片回到 1 天，记得的卡片按记忆难度逐步拉长。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '源代码以 MIT 许可发布。',
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
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            tooltip: '减少',
            icon: const Icon(Icons.remove_rounded, size: 17),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: value < 100 ? () => onChanged(value + 1) : null,
            tooltip: '增加',
            icon: const Icon(Icons.add_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: palette.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
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
          action,
        ],
      ),
    );
  }
}
