import 'package:flutter/material.dart';

class ReaderMenuSheet extends StatelessWidget {
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
  final VoidCallback? onAppearance;

  const ReaderMenuSheet({
    super.key,
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
    this.onAppearance,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 8),
            _Group(
              title: '内容',
              children: [
                if (showBookTree)
                  _ActionTile(
                    icon: Icons.menu_book_outlined,
                    title: '目录',
                    subtitle: '章节与文档结构',
                    onTap: disabled ? null : onBookTree,
                  ),
                _ActionTile(
                  icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  title: bookmarked ? '取消书签' : '添加书签',
                  subtitle: '标记当前阅读位置',
                  onTap: disabled ? null : onBookmark,
                ),
                _ActionTile(
                  icon: Icons.note_alt_outlined,
                  title: '笔记',
                  subtitle: '为当前页面添加笔记',
                  onTap: disabled ? null : onNote,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Group(
              title: '导航',
              children: [
                if (showSearch)
                  _ActionTile(
                    icon: Icons.search_rounded,
                    title: '搜索',
                    subtitle: '在文档中查找内容',
                    onTap: disabled ? null : onSearch,
                  ),
                if (showPageJump)
                  _ActionTile(
                    icon: Icons.find_in_page_outlined,
                    title: '跳转到页码',
                    subtitle: '快速前往指定页面',
                    onTap: disabled ? null : onPageJump,
                  ),
              ],
            ),
            if (showCrop) ...[
              const SizedBox(height: 12),
              _Group(
                title: '阅读工具',
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    secondary: const Icon(Icons.crop_outlined),
                    title: const Text('裁边'),
                    subtitle: const Text('减少 PDF 页面周围的空白'),
                    value: cropEnabled,
                    onChanged: disabled ? null : onCropChanged,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _Group(
              title: '显示',
              children: [
                _ActionTile(
                  icon: Icons.palette_outlined,
                  title: '外观',
                  subtitle: '主题、页面布局与阅读器控件',
                  onTap: onAppearance,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '阅读菜单',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: _withDividers(children)),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) result.add(const Divider(height: 1, indent: 56));
      result.add(items[i]);
    }
    return result;
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 62,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
