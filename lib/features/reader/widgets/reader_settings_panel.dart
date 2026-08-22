import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import '../models/reader_view_options.dart';
import '../services/crop_configuration_store.dart';
import 'crop_editor_dialog.dart';

/// 阅读器显示设置面板。
///
/// 这个 Widget 负责展示 UI 设置，同时提供 Commit 4 的裁剪模板编辑入口。
/// 裁剪配置由 CropConfigurationStore 持久化，ReaderEngine 会在下一次渲染时自动读取。
class ReaderSettingsPanel extends StatelessWidget {
  final ReaderViewOptions options;
  final ValueChanged<ReaderViewOptions> onChanged;
  final VoidCallback onReset;

  const ReaderSettingsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    required this.onReset,
  });

  Future<void> _editCropConfiguration(BuildContext context) async {
    final store = CropConfigurationStore.instance;
    final current = await store.getForCurrentDocument();

    if (!context.mounted) {
      return;
    }

    final result = await showDialog<CropConfiguration>(
      context: context,
      builder: (context) {
        return CropEditorDialog(
          initial: current ?? CropConfiguration.initial(),
        );
      },
    );

    if (result == null) {
      return;
    }

    await store.setForCurrentDocument(result);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('裁剪模板已保存，重新渲染页面后生效。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      children: [
        const Text(
          '阅读器显示',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        SwitchListTile(
          title: const Text('显示当前位置'),
          subtitle: const Text('显示当前章节、书籍页码和 PDF 页码'),
          value: options.showLocationBar,
          onChanged: (value) {
            onChanged(options.copyWith(showLocationBar: value));
          },
        ),

        SwitchListTile(
          title: const Text('显示搜索位置'),
          subtitle: const Text('在顶部位置栏显示最近一次搜索命中位置'),
          value: options.showSearchLocation,
          onChanged: options.showLocationBar
              ? (value) {
                  onChanged(options.copyWith(showSearchLocation: value));
                }
              : null,
        ),

        const Divider(),

        SwitchListTile(
          title: const Text('显示目录按钮'),
          value: options.showBookTreeButton,
          onChanged: (value) {
            onChanged(options.copyWith(showBookTreeButton: value));
          },
        ),

        SwitchListTile(
          title: const Text('显示搜索按钮'),
          value: options.showSearchButton,
          onChanged: (value) {
            onChanged(options.copyWith(showSearchButton: value));
          },
        ),

        SwitchListTile(
          title: const Text('显示页码跳转按钮'),
          value: options.showPageJumpButton,
          onChanged: (value) {
            onChanged(options.copyWith(showPageJumpButton: value));
          },
        ),

        SwitchListTile(
          title: const Text('显示裁边开关'),
          value: options.showCropMargins,
          onChanged: (value) {
            onChanged(options.copyWith(showCropMargins: value));
          },
        ),

        ListTile(
          leading: const Icon(Icons.crop),
          title: const Text('编辑裁剪模板'),
          subtitle: const Text('单栏、双栏、三栏、自定义区域、页码范围、继承与增量调整'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editCropConfiguration(context),
        ),

        SwitchListTile(
          title: const Text('显示底部控制栏'),
          value: options.showPageControls,
          onChanged: (value) {
            onChanged(options.copyWith(showPageControls: value));
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('恢复默认设置'),
          subtitle: const Text('恢复阅读器所有显示设置'),
          onTap: onReset,
        ),
      ],
    );
  }
}
