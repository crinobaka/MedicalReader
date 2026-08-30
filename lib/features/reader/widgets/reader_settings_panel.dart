import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import '../models/reader_view_options.dart';
import '../services/crop_configuration_store.dart';
import '../services/reader_ui_theme.dart';
import 'crop_editor_dialog.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('裁剪模板已保存并应用。')));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final width = MediaQuery.sizeOf(context).width;
    final list = Scrollbar(
      thumbVisibility: width >= 700,
      interactive: true,
      controller: scrollController,
      child: ListView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
        physics: const ClampingScrollPhysics(),
        children: [
          _section(context, '阅读器外观', '先选整体气质，再按习惯微调', [
            _ThemePresetSelector(value: options.themePreset, onChanged: (value) => onChanged(options.copyWith(themePreset: value))),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('悬浮式控件'), subtitle: const Text('工具栏悬浮在页面上方，不挤占正文空间'), value: options.floatingControls, onChanged: (value) => onChanged(options.copyWith(floatingControls: value))),
            _selectRow(context, Icons.view_agenda_outlined, '页面布局', _pageLayoutLabel(options.pageLayout), () async {
              final value = await _choose(context, '页面布局', options.pageLayout, const {
                'one': '单页', 'two': '双页（左右并排）', 'three': '三页（连续并排）',
              });
              if (value != null) onChanged(options.copyWith(pageLayout: value));
            }),
            _selectRow(context, Icons.vertical_align_top_rounded, '工具栏位置', _toolbarLabel(options.toolbarPosition), () async {
              final value = await _choose(context, '工具栏位置', options.toolbarPosition, const {'auto': '自动（推荐）', 'top': '顶部', 'bottom': '底部'});
              if (value != null) onChanged(options.copyWith(toolbarPosition: value));
            }),
            _selectRow(context, Icons.wallpaper_outlined, '阅读画布', _canvasLabel(options.canvasBackground), () async {
              final value = await _choose(context, '阅读画布', options.canvasBackground, const {'inherit': '跟随系统', 'paper': '纸张', 'dark': '暗色', 'custom': '自定义颜色（DIY）'});
              if (value != null) onChanged(options.copyWith(canvasBackground: value));
            }),
          ]),
          _section(context, '阅读时显示什么', '只留下真正需要的控件，减少长时间阅读的视觉噪音', [
            _switch(context, Icons.location_on_outlined, '当前位置', '章节、书籍页码和 PDF 页码', options.showLocationBar, (v) => onChanged(options.copyWith(showLocationBar: v))),
            _switch(context, Icons.manage_search_outlined, '搜索命中位置', '显示最近一次搜索命中的章节与页码', options.showSearchLocation, (v) => onChanged(options.copyWith(showSearchLocation: v)), enabled: options.showLocationBar),
            _switch(context, Icons.menu_book_outlined, '目录按钮', null, options.showBookTreeButton, (v) => onChanged(options.copyWith(showBookTreeButton: v))),
            _switch(context, Icons.search_rounded, '搜索按钮', null, options.showSearchButton, (v) => onChanged(options.copyWith(showSearchButton: v))),
            _switch(context, Icons.find_in_page_outlined, '页码跳转按钮', null, options.showPageJumpButton, (v) => onChanged(options.copyWith(showPageJumpButton: v))),
            _switch(context, Icons.swap_horiz_rounded, '底部翻页栏', '显示上一页、下一页和当前页码', options.showPageControls, (v) => onChanged(options.copyWith(showPageControls: v))),
          ]),
          _section(context, '页面裁剪', '设置这里只负责入口和显示控制', [
            _switch(context, Icons.crop_outlined, '显示裁剪控制', null, options.showCropMargins, (v) => onChanged(options.copyWith(showCropMargins: v))),
            _selectRow(context, Icons.view_column_outlined, '裁剪模板', '打开当前页可视化编辑器', () => _editCropConfiguration(context)),
          ]),
          _section(context, 'DIY', '普通用户可以忽略；高级用户保留自由度', [
            ExpansionTile(tilePadding: EdgeInsets.zero, leading: const Icon(Icons.tune_rounded), title: const Text('当前配置'), subtitle: Text('主题 ${options.themePreset} · ${_pageLayoutLabel(options.pageLayout)}'), children: [Align(alignment: Alignment.centerLeft, child: Text('主题：${options.themePreset}\n页面布局：${options.pageLayout}\n悬浮控件：${options.floatingControls ? '开启' : '关闭'}\n工具栏：${options.toolbarPosition}\n画布：${options.canvasBackground}\n\n高级 DIY 用户可以直接编辑 assets/ui/reader_theme.json；普通用户不需要修改代码。', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)))],),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.restore_rounded), title: const Text('恢复默认设置'), subtitle: const Text('恢复推荐设置'), onTap: onReset),
          ]),
        ],
      ),
    );
    if (scrollController != null) return list;
    return SizedBox(height: maxHeight, child: list);
  }

  Widget _section(BuildContext context, String title, String subtitle, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 18), child: Material(type: MaterialType.transparency, clipBehavior: Clip.antiAlias, child: DecoratedBox(decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55))), child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)), const SizedBox(height: 8), ...children])))));
  }

  Widget _switch(BuildContext context, IconData icon, String title, String? subtitle, bool value, ValueChanged<bool> onChanged, {bool enabled = true}) => SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, secondary: Icon(icon), title: Text(title), subtitle: subtitle == null ? null : Text(subtitle), value: value, onChanged: enabled ? onChanged : null);
  Widget _selectRow(BuildContext context, IconData icon, String title, String value, VoidCallback onTap) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(title), subtitle: Text(value), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap);
  Future<String?> _choose(BuildContext context, String title, String value, Map<String, String> items) => showDialog<String>(context: context, builder: (context) => SimpleDialog(title: Text(title), children: [for (final entry in items.entries) RadioListTile<String>(value: entry.key, groupValue: value, title: Text(entry.value), onChanged: (next) => Navigator.of(context).pop(next))]));
  String _toolbarLabel(String value) => const {'auto': '自动（推荐）', 'top': '顶部', 'bottom': '底部'}[value] ?? '自动（推荐）';
  String _canvasLabel(String value) => const {'inherit': '跟随系统', 'paper': '纸张', 'dark': '暗色', 'custom': '自定义颜色（DIY）'}[value] ?? '跟随系统';
  String _pageLayoutLabel(String value) => const {'one': '单页', 'two': '双页（左右并排）', 'three': '三页（连续并排）'}[value] ?? '单页';
}

class _ThemePresetSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ThemePresetSelector({required this.value, required this.onChanged});
  static const presets = [
    (id: 'google', name: 'Google', description: 'Material：清晰、亲和、强调层级', icon: Icons.auto_awesome_rounded),
    (id: 'apple', name: 'Apple', description: '轻量、留白、圆润、少干扰', icon: Icons.phone_iphone_rounded),
    (id: 'github', name: 'GitHub', description: '紧凑、直接、适合长时间桌面使用', icon: Icons.code_rounded),
  ];
  @override
  Widget build(BuildContext context) => Column(children: [for (final preset in presets) Padding(padding: const EdgeInsets.only(bottom: 8), child: _ThemePresetCard(preset: preset, selected: value == preset.id, onTap: () => onChanged(preset.id)))]);
}

class _ThemePresetCard extends StatelessWidget {
  final ({String id, String name, String description, IconData icon}) preset;
  final bool selected;
  final VoidCallback onTap;
  const _ThemePresetCard({required this.preset, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = ReaderUiTheme.resolve(preset.id, Theme.of(context).brightness);
    return Material(color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: preview.surface, borderRadius: BorderRadius.circular(preview.buttonRadius)), child: Icon(preset.icon, color: preview.accent)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(preset.description, style: Theme.of(context).textTheme.bodySmall)])), Radio<String>(value: preset.id, groupValue: selected ? preset.id : null, onChanged: (_) => onTap())]))));
  }
}
