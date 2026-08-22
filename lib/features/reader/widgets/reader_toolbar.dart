import 'package:flutter/material.dart';

/// Presentation-only toolbar for the Reader.
///
/// ReaderPage keeps ownership of navigation, search, bookmark, note and crop
/// actions. This widget only receives callbacks and current UI state.
class ReaderToolbar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool showBookTree;
  final bool showSearch;
  final bool showPageJump;
  final bool showCrop;
  final bool bookmarked;
  final bool cropEnabled;
  final bool disabled;
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
    return AppBar(
      title: title,
      actions: [
        if (showBookTree)
          IconButton(
            tooltip: '目录',
            onPressed: disabled ? null : onBookTree,
            icon: const Icon(Icons.menu_book),
          ),
        if (showSearch)
          IconButton(
            tooltip: '搜索 PDF (Ctrl+F)',
            onPressed: disabled ? null : onSearch,
            icon: const Icon(Icons.search),
          ),
        if (showPageJump)
          IconButton(
            tooltip: '跳转到页码 (G)',
            onPressed: disabled ? null : onPageJump,
            icon: const Icon(Icons.find_in_page),
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
        if (showCrop)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('裁边'),
              Switch(
                value: cropEnabled,
                onChanged: disabled ? null : onCropChanged,
              ),
            ],
          ),
        IconButton(
          tooltip: '阅读器设置',
          onPressed: disabled ? null : onSettings,
          icon: const Icon(Icons.tune),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
