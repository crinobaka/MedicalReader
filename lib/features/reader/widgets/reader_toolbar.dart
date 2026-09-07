import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reader_view_options_provider.dart';
import '../services/reader_ui_theme.dart';
import 'reader_menu_sheet.dart';

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

  Future<void> _showReaderMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => ReaderMenuSheet(
        showBookTree: showBookTree,
        showSearch: showSearch,
        showPageJump: showPageJump,
        showCrop: showCrop,
        bookmarked: bookmarked,
        cropEnabled: cropEnabled,
        disabled: disabled,
        onBookTree: () {
          Navigator.of(sheetContext).pop();
          onBookTree?.call();
        },
        onSearch: () {
          Navigator.of(sheetContext).pop();
          onSearch?.call();
        },
        onPageJump: () {
          Navigator.of(sheetContext).pop();
          onPageJump?.call();
        },
        onBookmark: () {
          Navigator.of(sheetContext).pop();
          onBookmark?.call();
        },
        onNote: () {
          Navigator.of(sheetContext).pop();
          onNote?.call();
        },
        onCropChanged: (value) {
          Navigator.of(sheetContext).pop();
          onCropChanged?.call(value);
        },
        onAppearance: () {
          Navigator.of(sheetContext).pop();
          onSettings?.call();
        },
      ),
    );
  }

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
        actions: compact ? _mobileActions(context) : _desktopActions(theme, context),
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

  List<Widget> _mobileActions(BuildContext context) => [
        if (showSearch)
          IconButton(
            tooltip: '搜索',
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
        IconButton(
          tooltip: '阅读菜单',
          onPressed: disabled ? null : () => _showReaderMenu(context),
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ];

  List<Widget> _desktopActions(ReaderUiTheme theme, BuildContext context) => [
        if (showBookTree) IconButton(tooltip: '目录', onPressed: disabled ? null : onBookTree, icon: const Icon(Icons.menu_book)),
        if (showSearch) IconButton(tooltip: '搜索 (Ctrl+F)', onPressed: disabled ? null : onSearch, icon: const Icon(Icons.search)),
        if (showPageJump) IconButton(tooltip: '跳转到页码 (G)', onPressed: disabled ? null : onPageJump, icon: const Icon(Icons.find_in_page)),
        IconButton(tooltip: bookmarked ? '取消书签' : '添加书签', onPressed: disabled ? null : onBookmark, icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border)),
        IconButton(tooltip: '添加笔记', onPressed: disabled ? null : onNote, icon: const Icon(Icons.note_alt_outlined)),
        if (showCrop)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.controlPadding.horizontal / 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('裁边', style: TextStyle(color: theme.muted)),
                Switch(value: cropEnabled, onChanged: disabled ? null : onCropChanged),
              ],
            ),
          ),
        IconButton(
          tooltip: '阅读菜单',
          onPressed: disabled ? null : () => _showReaderMenu(context),
          icon: const Icon(Icons.more_horiz_rounded),
        ),
        const SizedBox(width: 8),
      ];
}
