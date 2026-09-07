import 'package:flutter/material.dart';

import '../../reader/models/reader_view_options.dart';
import '../../reader/services/reader_ui_theme.dart';

class ReaderAppearanceSettings extends StatelessWidget {
  final ReaderViewOptions options;
  final ValueChanged<ReaderViewOptions> onChanged;
  final VoidCallback onReset;

  const ReaderAppearanceSettings({
    super.key,
    required this.options,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _section(context, '主题', '选择阅读时的整体视觉气质。', [
          _ThemeChoices(
            value: options.themePreset,
            onChanged: (value) => onChanged(options.copyWith(themePreset: value)),
          ),
          _switch(
            context,
            Icons.blur_on_outlined,
            '悬浮式控件',
            '工具栏悬浮在页面上方，不挤占正文空间。',
            options.floatingControls,
            (value) => onChanged(options.copyWith(floatingControls: value)),
          ),
        ]),
        _section(context, '页面', '控制正文区域如何铺开，以及工具栏放在哪里。', [
          _choice(
            context,
            Icons.view_agenda_outlined,
            '页面布局',
            _pageLayoutLabel(options.pageLayout),
            options.pageLayout,
            const {
              'one': '单页',
              'two': '双页（左右并排）',
              'three': '三页（连续并排）',
            },
            (value) => onChanged(options.copyWith(pageLayout: value)),
          ),
          _choice(
            context,
            Icons.vertical_align_top_rounded,
            '工具栏位置',
            _toolbarLabel(options.toolbarPosition),
            options.toolbarPosition,
            const {
              'auto': '自动（推荐）',
              'top': '顶部',
              'bottom': '底部',
            },
            (value) => onChanged(options.copyWith(toolbarPosition: value)),
          ),
          _choice(
            context,
            Icons.wallpaper_outlined,
            '阅读画布',
            _canvasLabel(options.canvasBackground),
            options.canvasBackground,
            const {
              'inherit': '跟随系统',
              'paper': '纸张',
              'dark': '暗色',
              'custom': '自定义颜色（DIY）',
            },
            (value) => onChanged(options.copyWith(canvasBackground: value)),
          ),
        ]),
        _section(context, '阅读时显示', '隐藏不需要的控件，让正文成为视觉中心。', [
          _switch(
            context,
            Icons.location_on_outlined,
            '当前位置',
            '显示章节、书籍页码和 PDF 页码。',
            options.showLocationBar,
            (value) => onChanged(options.copyWith(showLocationBar: value)),
          ),
          _switch(
            context,
            Icons.manage_search_outlined,
            '搜索命中位置',
            '显示最近一次搜索命中的章节与页码。',
            options.showSearchLocation,
            (value) => onChanged(options.copyWith(showSearchLocation: value)),
            enabled: options.showLocationBar,
          ),
          _switch(
            context,
            Icons.swap_horiz_rounded,
            '底部翻页栏',
            '显示上一页、下一页和当前页码。',
            options.showPageControls,
            (value) => onChanged(options.copyWith(showPageControls: value)),
          ),
        ]),
        _section(context, '快捷入口', '决定阅读器菜单里保留哪些常用入口。', [
          _switch(context, Icons.menu_book_outlined, '目录按钮', null,
              options.showBookTreeButton,
              (value) => onChanged(options.copyWith(showBookTreeButton: value))),
          _switch(context, Icons.search_rounded, '搜索按钮', null,
              options.showSearchButton,
              (value) => onChanged(options.copyWith(showSearchButton: value))),
          _switch(context, Icons.find_in_page_outlined, '页码跳转按钮', null,
              options.showPageJumpButton,
              (value) => onChanged(options.copyWith(showPageJumpButton: value))),
        ]),
        _section(context, '恢复', '只恢复阅读器显示配置，不影响书库和阅读进度。', [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_rounded),
            title: const Text('恢复默认设置'),
            subtitle: const Text('恢复推荐的主题、布局和控件配置。'),
            onTap: onReset,
          ),
        ]),
      ],
    );
  }

  Widget _section(BuildContext context, String title, String subtitle, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _switch(BuildContext context, IconData icon, String title, String? subtitle,
      bool value, ValueChanged<bool> onChanged, {bool enabled = true}) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _choice(BuildContext context, IconData icon, String title, String subtitle,
      String value, Map<String, String> choices, ValueChanged<String> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        final next = await showDialog<String>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: Text(title),
            children: [
              for (final entry in choices.entries)
                RadioListTile<String>(
                  value: entry.key,
                  groupValue: value,
                  title: Text(entry.value),
                  onChanged: (selected) => Navigator.of(dialogContext).pop(selected),
                ),
            ],
          ),
        );
        if (next != null) onChanged(next);
      },
    );
  }

  String _toolbarLabel(String value) =>
      const {'auto': '自动（推荐）', 'top': '顶部', 'bottom': '底部'}[value] ?? '自动（推荐）';

  String _canvasLabel(String value) => const {
        'inherit': '跟随系统',
        'paper': '纸张',
        'dark': '暗色',
        'custom': '自定义颜色（DIY）',
      }[value] ?? '跟随系统';

  String _pageLayoutLabel(String value) => const {
        'one': '单页',
        'two': '双页（左右并排）',
        'three': '三页（连续并排）',
      }[value] ?? '单页';
}

class _ThemeChoices extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ThemeChoices({required this.value, required this.onChanged});

  static const _presets = [
    (id: 'google', name: 'Google', description: 'Material：清晰、亲和、强调层级', icon: Icons.auto_awesome_rounded),
    (id: 'apple', name: 'Apple', description: '轻量、留白、圆润、少干扰', icon: Icons.phone_iphone_rounded),
    (id: 'github', name: 'GitHub', description: '紧凑、直接、适合长时间桌面使用', icon: Icons.code_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final preset in _presets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ThemeChoice(
              preset: preset,
              selected: value == preset.id,
              onTap: () => onChanged(preset.id),
            ),
          ),
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final ({String id, String name, String description, IconData icon}) preset;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice({required this.preset, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = ReaderUiTheme.resolve(preset.id, Theme.of(context).brightness);
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: preview.surface,
                  borderRadius: BorderRadius.circular(preview.buttonRadius),
                ),
                child: Icon(preset.icon, color: preview.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(preset.description, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Radio<String>(value: preset.id, groupValue: selected ? preset.id : null, onChanged: (_) => onTap()),
            ],
          ),
        ),
      ),
    );
  }
}
