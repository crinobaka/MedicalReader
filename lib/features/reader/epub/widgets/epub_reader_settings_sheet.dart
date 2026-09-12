import 'package:flutter/material.dart';

import '../../domain/models/reader_settings.dart';
import '../models/epub_book.dart';

class EpubReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;
  final List<EpubNavItem> navigation;
  final int currentChapter;
  final ValueChanged<EpubNavItem>? onNavigationSelected;
  final VoidCallback? onBookmark;
  final VoidCallback? onNote;
  final VoidCallback? onAnnotations;

  const EpubReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    this.navigation = const [],
    this.currentChapter = 0,
    this.onNavigationSelected,
    this.onBookmark,
    this.onNote,
    this.onAnnotations,
  });

  @override
  State<EpubReaderSettingsSheet> createState() => _EpubReaderSettingsSheetState();
}

class _EpubReaderSettingsSheetState extends State<EpubReaderSettingsSheet> {
  late ReaderSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(ReaderSettings value) {
    setState(() => _settings = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .5,
        maxChildSize: .96,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Text('阅读器', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text('统一面板：阅读方式、目录、标注和外观使用同一套 ReaderSettings。', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            _group(context, '快速操作', [
              _action(context, Icons.bookmark_add_outlined, '书签', '标记当前阅读位置', widget.onBookmark),
              _action(context, Icons.note_add_outlined, '笔记', '为当前章节创建阅读笔记', widget.onNote),
              _action(context, Icons.collections_bookmark_outlined, '标注与笔记', '查看高亮、书签和笔记', widget.onAnnotations),
            ]),
            _group(context, '目录', [
              if (widget.navigation.isEmpty)
                const ListTile(title: Text('暂无 EPUB 导航目录'))
              else
                for (final item in widget.navigation)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onNavigationSelected == null ? null : () => widget.onNavigationSelected!(item),
                  ),
            ]),
            _group(context, '主题与排版', [
              _label('主题'),
              SegmentedButton<ReaderTheme>(
                segments: const [
                  ButtonSegment(value: ReaderTheme.system, label: Text('系统')),
                  ButtonSegment(value: ReaderTheme.light, label: Text('浅色')),
                  ButtonSegment(value: ReaderTheme.dark, label: Text('深色')),
                  ButtonSegment(value: ReaderTheme.sepia, label: Text('护眼')),
                ],
                selected: {_settings.theme},
                onSelectionChanged: (v) => _update(_settings.copyWith(theme: v.first)),
              ),
              const SizedBox(height: 12),
              _slider('字号', _settings.fontSize, 12, 36, (v) => _update(_settings.copyWith(fontSize: v))),
              _slider('行高', _settings.lineHeight, 1, 2.4, (v) => _update(_settings.copyWith(lineHeight: v))),
              _slider('段落间距', _settings.paragraphSpacing, 0, 32, (v) => _update(_settings.copyWith(paragraphSpacing: v))),
              _slider('左右边距', _settings.horizontalPadding, 8, 56, (v) => _update(_settings.copyWith(horizontalPadding: v))),
              _slider('上下边距', _settings.verticalPadding, 0, 48, (v) => _update(_settings.copyWith(verticalPadding: v))),
            ]),
            _group(context, '阅读方式', [
              _label('方向'),
              SegmentedButton<ReaderReadingDirection>(
                segments: const [
                  ButtonSegment(value: ReaderReadingDirection.ltr, label: Text('横排')),
                  ButtonSegment(value: ReaderReadingDirection.rtl, label: Text('横排 RTL')),
                  ButtonSegment(value: ReaderReadingDirection.vertical, label: Text('竖排')),
                ],
                selected: {_settings.readingDirection},
                onSelectionChanged: (v) => _update(_settings.copyWith(readingDirection: v.first)),
              ),
              const SizedBox(height: 12),
              _label('翻页'),
              SegmentedButton<ReaderReadingMode>(
                segments: const [
                  ButtonSegment(value: ReaderReadingMode.paginated, label: Text('分页')),
                  ButtonSegment(value: ReaderReadingMode.continuous, label: Text('连续')),
                ],
                selected: {_settings.readingMode},
                onSelectionChanged: (v) => _update(_settings.copyWith(readingMode: v.first)),
              ),
            ]),
            _group(context, '阅读界面', [
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('悬浮控件'), subtitle: const Text('工具不挤占正文空间'), value: _settings.floatingControls, onChanged: (v) => _update(_settings.copyWith(floatingControls: v))),
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('位置栏'), value: _settings.showLocationBar, onChanged: (v) => _update(_settings.copyWith(showLocationBar: v))),
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('底部翻页栏'), value: _settings.showPageControls, onChanged: (v) => _update(_settings.copyWith(showPageControls: v))),
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('搜索按钮'), value: _settings.showSearchButton, onChanged: (v) => _update(_settings.copyWith(showSearchButton: v))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55))),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), ...children])),
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String title, String subtitle, VoidCallback? onTap) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap);
  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)));
  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$label  ${value.toStringAsFixed(label == '行高' ? 1 : 0)}'), Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged)]);
}
