import 'package:flutter/material.dart';

import '../domain/models/reader_settings.dart';
import '../epub/models/epub_book.dart';

/// The single settings surface shared by PDF and EPUB readers.
///
/// Feature-specific actions are injected so the panel stays independent from
/// either document engine while keeping one Hoshi-inspired interaction model.
class ReaderUnifiedSettingsPanel extends StatelessWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;
  final List<EpubNavItem> navigation;
  final int currentChapter;
  final ValueChanged<EpubNavItem>? onNavigationSelected;
  final List<Widget> extraSections;
  final VoidCallback? onBookmark;
  final VoidCallback? onNote;
  final VoidCallback? onAnnotations;
  final VoidCallback? onSearch;
  final VoidCallback? onReset;
  final ScrollController? scrollController;
  final bool showHeader;
  final bool showTypography;
  final bool showReadingMode;

  const ReaderUnifiedSettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    this.navigation = const [],
    this.currentChapter = 0,
    this.onNavigationSelected,
    this.extraSections = const [],
    this.onBookmark,
    this.onNote,
    this.onAnnotations,
    this.onSearch,
    this.onReset,
    this.scrollController,
    this.showHeader = true,
    this.showTypography = true,
    this.showReadingMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (showHeader) ...[
        Text('阅读器', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text('PDF 与 EPUB 共用同一套阅读设置、操作入口和视觉层级。', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
      if (onBookmark != null || onNote != null || onAnnotations != null || onSearch != null)
        _group(context, '快速操作', [
          if (onSearch != null) _action(Icons.search_rounded, '搜索', '在当前文档中查找内容', onSearch),
          if (onBookmark != null) _action(Icons.bookmark_add_outlined, '书签', '标记当前阅读位置', onBookmark),
          if (onNote != null) _action(Icons.note_add_outlined, '笔记', '为当前位置创建阅读笔记', onNote),
          if (onAnnotations != null) _action(Icons.collections_bookmark_outlined, '标注与笔记', '查看高亮、书签和笔记', onAnnotations),
        ]),
      if (navigation.isNotEmpty || onNavigationSelected != null)
        _group(context, '目录', [
          if (navigation.isEmpty)
            const ListTile(title: Text('暂无目录'))
          else
            for (var index = 0; index < navigation.length; index++)
              ListTile(
                dense: true,
                selected: index == currentChapter,
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(navigation[index].title, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onNavigationSelected == null ? null : () => onNavigationSelected!(navigation[index]),
              ),
        ]),
      if (showTypography)
        _group(context, '主题与排版', [
          _theme(context),
          _slider('字号', settings.fontSize, 12, 36, (v) => _update(settings.copyWith(fontSize: v))),
          _slider('行高', settings.lineHeight, 1, 2.4, (v) => _update(settings.copyWith(lineHeight: v))),
          _slider('段落间距', settings.paragraphSpacing, 0, 32, (v) => _update(settings.copyWith(paragraphSpacing: v))),
          _slider('左右边距', settings.horizontalPadding, 8, 56, (v) => _update(settings.copyWith(horizontalPadding: v))),
          _slider('上下边距', settings.verticalPadding, 0, 48, (v) => _update(settings.copyWith(verticalPadding: v))),
        ]),
      if (showReadingMode)
        _group(context, '阅读方式', [
          _label('方向'),
          SegmentedButton<ReaderReadingDirection>(
            segments: const [
              ButtonSegment(value: ReaderReadingDirection.ltr, label: Text('横排')),
              ButtonSegment(value: ReaderReadingDirection.rtl, label: Text('横排 RTL')),
              ButtonSegment(value: ReaderReadingDirection.vertical, label: Text('竖排')),
            ],
            selected: {settings.readingDirection},
            onSelectionChanged: (v) => _update(settings.copyWith(readingDirection: v.first)),
          ),
          const SizedBox(height: 12),
          _label('翻页'),
          SegmentedButton<ReaderReadingMode>(
            segments: const [
              ButtonSegment(value: ReaderReadingMode.paginated, label: Text('分页')),
              ButtonSegment(value: ReaderReadingMode.continuous, label: Text('连续')),
            ],
            selected: {settings.readingMode},
            onSelectionChanged: (v) => _update(settings.copyWith(readingMode: v.first)),
          ),
        ]),
      _group(context, '阅读界面', [
        _switch('悬浮控件', '工具不挤占正文空间', settings.floatingControls, (v) => _update(settings.copyWith(floatingControls: v))),
        _switch('位置栏', null, settings.showLocationBar, (v) => _update(settings.copyWith(showLocationBar: v))),
        _switch('搜索位置', '显示最近一次搜索命中的章节或页码', settings.showSearchLocation, (v) => _update(settings.copyWith(showSearchLocation: v)), enabled: settings.showLocationBar),
        _switch('目录按钮', null, settings.showBookTreeButton, (v) => _update(settings.copyWith(showBookTreeButton: v))),
        _switch('搜索按钮', null, settings.showSearchButton, (v) => _update(settings.copyWith(showSearchButton: v))),
        _switch('页码跳转按钮', null, settings.showPageJumpButton, (v) => _update(settings.copyWith(showPageJumpButton: v))),
        _switch('底部翻页栏', null, settings.showPageControls, (v) => _update(settings.copyWith(showPageControls: v))),
      ]),
      ...extraSections,
      if (onReset != null)
        _group(context, '维护', [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_rounded),
            title: const Text('恢复默认设置'),
            onTap: onReset,
          ),
        ]),
    ];

    return ListView(
      controller: scrollController,
      primary: scrollController == null,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      physics: const ClampingScrollPhysics(),
      children: children,
    );
  }

  void _update(ReaderSettings value) => onChanged(value);

  Widget _theme(BuildContext context) => Column(
        children: [
          _label('主题'),
          SegmentedButton<ReaderTheme>(
            segments: const [
              ButtonSegment(value: ReaderTheme.system, label: Text('系统')),
              ButtonSegment(value: ReaderTheme.light, label: Text('浅色')),
              ButtonSegment(value: ReaderTheme.dark, label: Text('深色')),
              ButtonSegment(value: ReaderTheme.sepia, label: Text('护眼')),
            ],
            selected: {settings.theme},
            onSelectionChanged: (v) => _update(settings.copyWith(theme: v.first)),
          ),
        ],
      );

  Widget _group(BuildContext context, String title, List<Widget> children) {
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...children,
          ]),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String title, String subtitle, VoidCallback? onTap) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );

  Widget _switch(String title, String? subtitle, bool value, ValueChanged<bool> onChanged, {bool enabled = true}) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: enabled ? onChanged : null,
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label  ${value.toStringAsFixed(label == '行高' ? 1 : 0)}'),
          Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ],
      );
}
