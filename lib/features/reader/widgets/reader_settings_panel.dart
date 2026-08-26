import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import '../models/reader_view_options.dart';
import '../services/crop_configuration_store.dart';
import 'crop_editor_dialog.dart';

/// Settings content only. It deliberately does not create its own ScrollView.
/// The host (SettingsPage or a modal sheet) owns scrolling, so a user can drag
/// anywhere on the sheet/page instead of having to catch the edge of a nested list.
class ReaderSettingsPanel extends StatelessWidget {
  final ReaderViewOptions options;
  final ValueChanged<ReaderViewOptions> onChanged;
  final VoidCallback onReset;
  final Future<void> Function()? onCropConfigurationChanged;

  const ReaderSettingsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    required this.onReset,
    this.onCropConfigurationChanged,
  });

  Future<void> _editCropConfiguration(BuildContext context) async {
    final store = CropConfigurationStore.instance;
    final current = await store.getForCurrentDocument();
    if (!context.mounted) return;
    final result = await showDialog<CropConfiguration>(
      context: context,
      builder: (context) => CropEditorDialog(
        initial: current ?? CropConfiguration.initial(),
      ),
    );
    if (result == null) return;
    await store.setForCurrentDocument(result);
    await onCropConfigurationChanged?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('裁剪模板已保存并应用。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(context, '阅读器外观'),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'google',
                label: Text('Google'),
                icon: Icon(Icons.auto_awesome),
              ),
              ButtonSegment(
                value: 'apple',
                label: Text('Apple'),
                icon: Icon(Icons.apple),
              ),
              ButtonSegment(
                value: 'github',
                label: Text('GitHub'),
                icon: Icon(Icons.code),
              ),
            ],
            selected: {
              if (['google', 'apple', 'github'].contains(options.themePreset))
                options.themePreset
              else
                'google',
            },
            onSelectionChanged: (value) =>
                onChanged(options.copyWith(themePreset: value.first)),
          ),
          const SizedBox(height: 4),
          const Text(
            '三套预设会同时改变颜色、圆角、按钮密度和工具栏质感。',
            style: TextStyle(fontSize: 12),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('悬浮式控件'),
            subtitle: const Text('工具栏浮在页面上方，内容区域更完整'),
            value: options.floatingControls,
            onChanged: (value) =>
                onChanged(options.copyWith(floatingControls: value)),
          ),
          DropdownButtonFormField<String>(
            value: options.toolbarPosition,
            decoration: const InputDecoration(labelText: '工具栏位置'),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('自动（推荐）')),
              DropdownMenuItem(value: 'top', child: Text('顶部')),
              DropdownMenuItem(value: 'bottom', child: Text('底部')),
            ],
            onChanged: (value) => value == null
                ? null
                : onChanged(options.copyWith(toolbarPosition: value)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: options.canvasBackground,
            decoration: const InputDecoration(labelText: '阅读画布背景'),
            items: const [
              DropdownMenuItem(value: 'inherit', child: Text('跟随系统')),
              DropdownMenuItem(value: 'paper', child: Text('纸张')),
              DropdownMenuItem(value: 'dark', child: Text('暗色')),
              DropdownMenuItem(value: 'custom', child: Text('自定义颜色（API）')),
            ],
            onChanged: (value) => value == null
                ? null
                : onChanged(options.copyWith(canvasBackground: value)),
          ),
          const Divider(height: 32),
          _sectionTitle(context, '显示控件'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示当前位置'),
            subtitle: const Text('章节、书籍页码和 PDF 页码'),
            value: options.showLocationBar,
            onChanged: (v) => onChanged(options.copyWith(showLocationBar: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示搜索位置'),
            subtitle: const Text('显示最近一次搜索命中位置'),
            value: options.showSearchLocation,
            onChanged: options.showLocationBar
                ? (v) => onChanged(options.copyWith(showSearchLocation: v))
                : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示目录按钮'),
            value: options.showBookTreeButton,
            onChanged: (v) => onChanged(options.copyWith(showBookTreeButton: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示搜索按钮'),
            value: options.showSearchButton,
            onChanged: (v) => onChanged(options.copyWith(showSearchButton: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示页码跳转按钮'),
            value: options.showPageJumpButton,
            onChanged: (v) => onChanged(options.copyWith(showPageJumpButton: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示底部控制栏'),
            value: options.showPageControls,
            onChanged: (v) => onChanged(options.copyWith(showPageControls: v)),
          ),
          const Divider(height: 32),
          _sectionTitle(context, '页面裁剪'),
          const SizedBox(height: 4),
          const Text('裁剪模板决定 PDF 页面实际显示哪些区域。'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示裁剪控制'),
            value: options.showCropMargins,
            onChanged: (v) => onChanged(options.copyWith(showCropMargins: v)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_column_outlined),
            title: const Text('编辑并应用裁剪模板'),
            subtitle: const Text('实时预览单栏、双栏、三栏和自定义区域'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editCropConfiguration(context),
          ),
          const Divider(height: 32),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('DIY 指南'),
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  '主题：google / apple / github / custom。\n'
                  '工具栏：floatingControls 控制悬浮，toolbarPosition 控制位置。\n'
                  '画布：canvasBackground 可设 inherit / paper / dark / custom。\n'
                  'customCanvasColor 使用 ARGB 整数。\n\n'
                  '设计原则：普通用户只需要选择预设；DIY 用户再修改配置。不要为了隐藏一个按钮去改 ReaderPage。',
                ),
              ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore),
            title: const Text('恢复默认设置'),
            onTap: onReset,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
