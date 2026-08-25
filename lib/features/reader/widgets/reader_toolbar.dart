import 'package:flutter/material.dart';

import '../services/reader_ui_theme.dart';

class ReaderToolbar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool showBookTree;
  final bool showSearch;
  final bool showPageJump;
  final bool showCrop;
  final bool bookmarked;
  final bool cropEnabled;
  final bool disabled;
  final bool floating;
  final String themePreset;
  final VoidCallback? onBookTree;
  final VoidCallback? onSearch;
  final VoidCallback? onPageJump;
  final VoidCallback? onBookmark;
  final VoidCallback? onNote;
  final ValueChanged<bool>? onCropChanged;
  final VoidCallback? onSettings;

  const ReaderToolbar({
    super.key,
    this.title,
    required this.showBookTree,
    required this.showSearch,
    required this.showPageJump,
    required this.showCrop,
    required this.bookmarked,
    required this.cropEnabled,
    required this.disabled,
    this.floating = true,
    this.themePreset = 'google',
    this.onBookTree,
    this.onSearch,
    this.onPageJump,
    this.onBookmark,
    this.onNote,
    this.onCropChanged,
    this.onSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final theme = ReaderUiTheme.resolve(themePreset, Theme.of(context).brightness);
    final bar = AppBar(
      title: title,
      backgroundColor: floating ? theme.surface : null,
      foregroundColor: floating ? theme.foreground : null,
      elevation: floating ? theme.elevation : null,
      scrolledUnderElevation: floating ? theme.elevation : null,
      shape: floating ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radius)) : null,
      actions: compact ? _mobileActions(theme) : _desktopActions(theme),
    );
    if (!floating) return bar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: ClipRRect(borderRadius: BorderRadius.circular(theme.radius), child: bar),
    );
  }

  List<Widget> _mobileActions(ReaderUiTheme theme) => [
        if (showSearch) IconButton(tooltip: '搜索 PDF', onPressed: disabled ? null : onSearch, icon: const Icon(Icons.search)),
        IconButton(tooltip: bookmarked ? '取消书签' : '添加书签', onPressed: disabled ? null : onBookmark, icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border)),
        IconButton(tooltip: '添加笔记', onPressed: disabled ? null : onNote, icon: const Icon(Icons.note_alt_outlined)),
        PopupMenuButton<String>(
          tooltip: '更多阅读操作',
          onSelected: (value) {
            switch (value) {
              case 'tree': onBookTree?.call(); break;
              case 'jump': onPageJump?.call(); break;
              case 'settings': onSettings?.call(); break;
            }
          },
          itemBuilder: (context) => [
            if (showBookTree) const PopupMenuItem(value: 'tree', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.menu_book), title: Text('目录'))),
            if (showPageJump) const PopupMenuItem(value: 'jump', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.find_in_page), title: Text('跳转到页码'))),
            if (showCrop) PopupMenuItem(enabled: false, child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.crop), title: const Text('裁边'), trailing: Switch(value: cropEnabled, onChanged: disabled ? null : onCropChanged))),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'settings', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.tune), title: Text('阅读器设置'))),
          ],
        ),
      ];

  List<Widget> _desktopActions(ReaderUiTheme theme) => [
        if (showBookTree) IconButton(tooltip: '目录', onPressed: disabled ? null : onBookTree, icon: const Icon(Icons.menu_book)),
        if (showSearch) IconButton(tooltip: '搜索 PDF (Ctrl+F)', onPressed: disabled ? null : onSearch, icon: const Icon(Icons.search)),
        if (showPageJump) IconButton(tooltip: '跳转到页码 (G)', onPressed: disabled ? null : onPageJump, icon: const Icon(Icons.find_in_page)),
        IconButton(tooltip: bookmarked ? '取消书签' : '添加书签', onPressed: disabled ? null : onBookmark, icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border)),
        IconButton(tooltip: '添加笔记', onPressed: disabled ? null : onNote, icon: const Icon(Icons.note_alt_outlined)),
        if (showCrop) Row(mainAxisSize: MainAxisSize.min, children: [const Text('裁边'), Switch(value: cropEnabled, onChanged: disabled ? null : onCropChanged)]),
        IconButton(tooltip: '阅读器设置', onPressed: disabled ? null : onSettings, icon: const Icon(Icons.tune)),
        const SizedBox(width: 8),
      ];
}
