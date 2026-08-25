import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import '../models/reader_view_options.dart';
import '../services/crop_configuration_store.dart';
import 'crop_editor_dialog.dart';

class ReaderSettingsPanel extends StatelessWidget {
  final ReaderViewOptions options;
  final ValueChanged<ReaderViewOptions> onChanged;
  final VoidCallback onReset;
  final Future<void> Function()? onCropConfigurationChanged;

  const ReaderSettingsPanel({super.key, required this.options, required this.onChanged, required this.onReset, this.onCropConfigurationChanged});

  Future<void> _editCropConfiguration(BuildContext context) async {
    final store = CropConfigurationStore.instance;
    final current = await store.getForCurrentDocument();
    if (!context.mounted) return;
    final result = await showDialog<CropConfiguration>(context: context, builder: (context) => CropEditorDialog(initial: current ?? CropConfiguration.initial()));
    if (result == null) return;
    await store.setForCurrentDocument(result);
    await onCropConfigurationChanged?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('裁剪模板已保存并应用。')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      children: [
        const Text('阅读器外观', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'google', label: Text('Google'), icon: Icon(Icons.auto_awesome)),
            ButtonSegment(value: 'apple', label: Text('Apple'), icon: Icon(Icons.apple)),
            ButtonSegment(value: 'github', label: Text('GitHub'), icon: Icon(Icons.code)),
          ],
          selected: {if (['google', 'apple', 'github'].contains(options.themePreset)) options.themePreset else 'google'},
          onSelectionChanged: (value) => onChanged(options.copyWith(themePreset: value.first)),
        ),
        SwitchListTile(
          title: const Text('悬浮式控件'),
          subtitle: const Text('工具栏浮在页面上方，窄屏也保持轻量操作区'),
          value: options.floatingControls,
          onChanged: (value) => onChanged(options.copyWith(floatingControls: value)),
        ),
        DropdownButtonFormField<String>(
          value: options.toolbarPosition,
          decoration: const InputDecoration(labelText: '工具栏位置'),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('自动（推荐）')),
            DropdownMenuItem(value: 'top', child: Text('顶部')),
            DropdownMenuItem(value: 'bottom', child: Text('底部')),
          ],
          onChanged: (value) => value == null ? null : onChanged(options.copyWith(toolbarPosition: value)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: options.canvasBackground,
          decoration: const InputDecoration(labelText: '阅读画布背景'),
          items: const [
            DropdownMenuItem(value: 'inherit', child: Text('跟随系统')),
            DropdownMenuItem(value: 'paper', child: Text('纸张')),
            DropdownMenuItem(value: 'dark', child: Text('暗色')),
            DropdownMenuItem(value: 'custom', child: Text('自定义颜色（API）')),
          ],
          onChanged: (value) => value == null ? null : onChanged(options.copyWith(canvasBackground: value)),
        ),
        const Divider(height: 28),
        const Text('显示控件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SwitchListTile(title: const Text('显示当前位置'), subtitle: const Text('当前章节、书籍页码和 PDF 页码'), value: options.showLocationBar, onChanged: (v) => onChanged(options.copyWith(showLocationBar: v))),
        SwitchListTile(title: const Text('显示搜索位置'), subtitle: const Text('在顶部显示最近一次搜索命中位置'), value: options.showSearchLocation, onChanged: options.showLocationBar ? (v) => onChanged(options.copyWith(showSearchLocation: v)) : null),
        SwitchListTile(title: const Text('显示目录按钮'), value: options.showBookTreeButton, onChanged: (v) => onChanged(options.copyWith(showBookTreeButton: v))),
        SwitchListTile(title: const Text('显示搜索按钮'), value: options.showSearchButton, onChanged: (v) => onChanged(options.copyWith(showSearchButton: v))),
        SwitchListTile(title: const Text('显示页码跳转按钮'), value: options.showPageJumpButton, onChanged: (v) => onChanged(options.copyWith(showPageJumpButton: v))),
        SwitchListTile(title: const Text('显示底部控制栏'), value: options.showPageControls, onChanged: (v) => onChanged(options.copyWith(showPageControls: v))),
        const Divider(height: 28),
        const Text('页面裁剪 / 双栏 / 三栏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('裁剪模板决定 PDF 页面实际显示哪些区域。保存后会立即应用。'),
        SwitchListTile(title: const Text('显示裁剪控制'), value: options.showCropMargins, onChanged: (v) => onChanged(options.copyWith(showCropMargins: v))),
        ListTile(leading: const Icon(Icons.view_column_outlined), title: const Text('编辑并应用裁剪模板'), subtitle: const Text('实时预览单栏、双栏、三栏和自定义区域'), trailing: const Icon(Icons.chevron_right), onTap: () => _editCropConfiguration(context)),
        const Divider(height: 28),
        const ExpansionTile(
          leading: Icon(Icons.tune),
          title: Text('DIY 指南'),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('主题值：google / apple / github / custom。\n工具栏：floatingControls 控制悬浮，toolbarPosition 控制位置。\n画布：canvasBackground 可设 inherit / paper / dark / custom。\ncustomCanvasColor 使用 ARGB 整数。\n后续新增控件时，优先通过 ReaderViewOptions 暴露显示、位置、尺寸或样式入口，而不是把布局写死在 ReaderPage。'),
            ),
          ],
        ),
        ListTile(leading: const Icon(Icons.restore), title: const Text('恢复默认设置'), onTap: onReset),
      ],
    );
  }
}
