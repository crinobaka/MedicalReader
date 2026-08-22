import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import '../models/reader_view_options.dart';
import '../services/crop_configuration_store.dart';
import 'crop_editor_dialog.dart';

/// 阅读器显示设置。
///
/// UI 配置与 PDF 裁剪配置分开：前者控制控件是否显示，后者决定页面如何裁剪。
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

    // ReaderPage 提供这个回调时，保存配置后立即重新渲染当前页面。
    // 没有回调时，配置仍然已经持久化，下一次打开 Reader 会读取它。
    await onCropConfigurationChanged?.call();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('裁剪模板已保存并应用。双栏、三栏和自定义区域会立即影响当前页面。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      children: [
        const Text('阅读器显示', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('显示当前位置'),
          subtitle: const Text('当前章节、书籍页码和 PDF 页码'),
          value: options.showLocationBar,
          onChanged: (value) => onChanged(options.copyWith(showLocationBar: value)),
        ),
        SwitchListTile(
          title: const Text('显示搜索位置'),
          subtitle: const Text('在顶部显示最近一次搜索命中位置'),
          value: options.showSearchLocation,
          onChanged: options.showLocationBar
              ? (value) => onChanged(options.copyWith(showSearchLocation: value))
              : null,
        ),
        const Divider(),
        const Text('界面控件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('显示目录按钮'),
          subtitle: const Text('顶部工具栏中的目录入口'),
          value: options.showBookTreeButton,
          onChanged: (value) => onChanged(options.copyWith(showBookTreeButton: value)),
        ),
        SwitchListTile(
          title: const Text('显示搜索按钮'),
          subtitle: const Text('顶部工具栏中的 PDF 搜索入口'),
          value: options.showSearchButton,
          onChanged: (value) => onChanged(options.copyWith(showSearchButton: value)),
        ),
        SwitchListTile(
          title: const Text('显示页码跳转按钮'),
          subtitle: const Text('顶部工具栏中的页码跳转入口'),
          value: options.showPageJumpButton,
          onChanged: (value) => onChanged(options.copyWith(showPageJumpButton: value)),
        ),
        SwitchListTile(
          title: const Text('显示底部控制栏'),
          subtitle: const Text('页面底部的上一页/下一页等控制'),
          value: options.showPageControls,
          onChanged: (value) => onChanged(options.copyWith(showPageControls: value)),
        ),
        const Divider(),
        const Text('页面裁剪 / 双栏 / 三栏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          '裁剪模板决定 PDF 页面实际显示哪些区域：单栏显示整页，双栏拆成左右两块，三栏拆成三块，自定义按矩形区域显示。保存后会立即应用。',
        ),
        SwitchListTile(
          title: const Text('显示裁剪控制'),
          subtitle: const Text('控制阅读器顶部是否显示“裁边”开关；关闭不会删除已保存的裁剪模板'),
          value: options.showCropMargins,
          onChanged: (value) => onChanged(options.copyWith(showCropMargins: value)),
        ),
        ListTile(
          leading: const Icon(Icons.view_column_outlined),
          title: const Text('编辑并应用裁剪模板'),
          subtitle: const Text('实时预览单栏、双栏、三栏和自定义区域，保存后立即刷新当前 PDF 页面'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editCropConfiguration(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('恢复默认设置'),
          subtitle: const Text('恢复阅读器显示控件设置'),
          onTap: onReset,
        ),
      ],
    );
  }
}
