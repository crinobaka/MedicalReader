import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/models/reader_settings.dart';
import '../models/crop_configuration.dart';
import '../models/reader_view_options.dart';
import '../services/crop_configuration_store.dart';
import '../services/reader_settings_bridge.dart';
import 'crop_editor_dialog.dart';
import 'reader_unified_settings_panel.dart';

/// PDF adapter for the shared Hoshi-style reader settings surface.
///
/// ReaderViewOptions remains the PDF rendering contract for compatibility;
/// ReaderSettings is the UI/domain contract shared with EPUB.
class ReaderSettingsPanel extends StatelessWidget {
  final ReaderViewOptions options;
  final ValueChanged<ReaderViewOptions> onChanged;
  final VoidCallback onReset;
  final Future<void> Function()? onCropConfigurationChanged;
  final ui.Image? previewImage;
  final ScrollController? scrollController;

  const ReaderSettingsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    required this.onReset,
    this.onCropConfigurationChanged,
    this.previewImage,
    this.scrollController,
  });

  Future<void> _editCropConfiguration(BuildContext context) async {
    final store = CropConfigurationStore.instance;
    final current = await store.getForCurrentDocument();
    if (!context.mounted) return;
    final result = await showDialog<CropConfiguration>(
      context: context,
      builder: (context) => CropEditorDialog(
        initial: current ?? CropConfiguration.initial(),
        previewImage: previewImage,
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
    final settings = ReaderSettingsBridge.fromViewOptions(options);
    return ReaderUnifiedSettingsPanel(
      settings: settings,
      onChanged: (next) => onChanged(ReaderSettingsBridge.toViewOptions(next)),
      scrollController: scrollController,
      showTypography: false,
      showReadingMode: false,
      onReset: onReset,
      extraSections: [
        _section(
          context,
          '页面裁剪',
          '裁剪属于 PDF 渲染能力，但入口仍然和 EPUB 使用同一面板。',
          [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.crop_outlined),
              title: const Text('显示裁剪控制'),
              value: options.showCropMargins,
              onChanged: (v) => onChanged(options.copyWith(showCropMargins: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.view_column_outlined),
              title: const Text('裁剪模板'),
              subtitle: const Text('打开当前页可视化编辑器'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editCropConfiguration(context),
            ),
          ],
        ),
        _section(
          context,
          'PDF 专属',
          '保留 PDF 的渲染选项，不再复制一套阅读器外观面板。',
          [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.view_agenda_outlined),
              title: const Text('页面布局'),
              subtitle: Text(_pageLayoutLabel(options.pageLayout)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _choosePageLayout(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _choosePageLayout(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('页面布局'),
        children: [
          for (final entry in const {
            'one': '单页',
            'two': '双页（左右并排）',
            'three': '三页（连续并排）',
          }.entries)
            RadioListTile<String>(
              value: entry.key,
              groupValue: options.pageLayout,
              title: Text(entry.value),
              onChanged: (next) => Navigator.of(context).pop(next),
            ),
        ],
      ),
    );
    if (value != null) onChanged(options.copyWith(pageLayout: value));
  }

  Widget _section(BuildContext context, String title, String subtitle, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  String _pageLayoutLabel(String value) => const {
        'one': '单页',
        'two': '双页（左右并排）',
        'three': '三页（连续并排）',
      }[value] ?? '单页';
}
