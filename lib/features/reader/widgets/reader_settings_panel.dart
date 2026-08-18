import 'package:flutter/material.dart';

import '../models/reader_view_options.dart';

/// 阅读器显示设置面板。
///
/// 这个 Widget 只负责“展示设置”和返回新的配置。
/// 它不直接操作 Riverpod，也不保存数据。
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
