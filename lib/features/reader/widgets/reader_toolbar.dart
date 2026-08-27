import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reader_view_options_provider.dart';
import '../services/reader_ui_theme.dart';

class ReaderToolbar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool showBookTree;
  final bool showSearch;
  final bool showPageJump;
  final bool showCrop;
  final bool bookmarked;
  final bool cropEnabled;
  final bool disabled;
  final bool? floating;
  final String? themePreset;
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
    this.floating,
    this.themePreset,
    this.onBookTree,
    this.onSearch,
    this.onPageJump,
    this.onBookmark,
    this.onNote,
    this.onCropChanged,
    this.onSettings,
  });

  @override
  Size get preferredSize => Size.fromHeight(floating == false ? kToolbarHeight : 64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(readerViewOptionsProvider);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final effectiveFloating = floating ?? options.floatingControls;
    final effectivePreset = themePreset ?? options.themePreset;
    final theme = ReaderUiTheme.resolve(effectivePreset, Theme.of(context).brightness);

    final toolbarTheme = Theme.of(context).copyWith(
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: theme.foreground,
          backgroundColor: theme.accent.withValues(alpha: theme.buttonOpacity),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.buttonRadius),
            side: effectivePreset == 'github'
                ? BorderSide(color: theme.border)
                : BorderSide.none,
          ),
          minimumSize: const Size(44, 44),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(theme.accent),
      ),
    );

    final bar = Theme(
      data: toolbarTheme,
      child: AppBar(
        toolbarHeight: theme.toolbarHeight,
        title: title,
        backgroundColor: effectiveFloating ? theme.surface : null,
        foregroundColor: effectiveFloating ? theme.foreground : null,
        elevation: effectiveFloating ? theme.elevation : null,
        scrolledUnderElevation: effectiveFloating ? theme.elevation : null,
        shape: effectiveFloating
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radius),
                side: effectivePreset == 'github'
                    ? BorderSide(color: theme.border)
                    : BorderSide.none,
              )
            : null,
        titleSpacing: compact ? 12 : 16,
        actionsPadding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
        actions: compact ? _mobileActions(theme) : _desktopActions(theme),
      ),
    );

    if (!effectiveFloating) return bar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radius),
        child: bar,
      ),
    );
  }

  List<Widget> _mobileActions(ReaderUiTheme theme) => [
        if (showSearch)
          IconButton(
            tooltip: '搜索 PDF',
            onPressed: disabled ? null : onSearch,
            icon: const Icon(Icons.search),
          ),
        IconButton(
          tooltip: bookmarked ? '取消书签' : '添加书签',
          onPressed: disabled ? null : onBookmark,
          icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
        ),
        IconButton(
          tooltip: '添加笔记',
          onPressed: disabled ? null : onNote,
          icon: const Icon(Icons.note_alt_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: '更多阅读操作',
          onSelected: (value) {
            switch (value) {
              case 'tree': onBookTree?.call();
              case 'jump': onPageJump?.call();
              case 'settings': onSettings?.call();
            }
          },
          itemBuilder: (context) => [
            if (showBookTree)
              const PopupMenuItem(
                value: 'tree',
                child: Row(children: [Icon(Icons.menu_book), SizedBox(width: 12), Text('目录')]),
              ),
            if (showPageJump)
              const PopupMenuItem(
                value: 'jump',
                child: Row(children: [Icon(Icons.find_in_page), SizedBox(width: 12), Text('跳转到页码')]),
              ),
            if (showCrop)
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    const Icon(Icons.crop),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('裁边')),
                    Switch(value: cropEnabled, onChanged: disabled ? null : onCropChanged),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'settings',
              child: Row(children: [Icon(Icons.tune), SizedBox(width: 12), Text('阅读器设置')]),
            ),
          ],
        ),
      ];

  List<Widget> _desktopActions(ReaderUiTheme theme) => [
        if (showBookTree) IconButton(tooltip: '目录', onPressed: disabled ? null : onBookTree, icon: const Icon(Icons.menu_book)),
        if (showSearch) IconButton(tooltip: '搜索 PDF (Ctrl+F)', onPressed: disabled ? null : onSearch, icon: const Icon(Icons.search)),
        if (showPageJump) IconButton(tooltip: '跳转到页码 (G)', onPressed: disabled ? null : onPageJump, icon: const Icon(Icons.find_in_page)),
        IconButton(tooltip: bookmarked ? '取消书签' : '添加书签', onPressed: disabled ? null : onBookmark, icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border)),
        IconButton(tooltip: '添加笔记', onPressed: disabled ? null : onNote, icon: const Icon(Icons.note_alt_outlined)),
        if (showCrop)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.controlPadding.horizontal / 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('裁边', style: TextStyle(color: theme.muted)),
              Switch(value: cropEnabled, onChanged: disabled ? null : onCropChanged),
            ]),
          ),
        IconButton(tooltip: '阅读器设置', onPressed: disabled ? null : onSettings, icon: const Icon(Icons.tune)),
        const SizedBox(width: 8),
      ];
}
