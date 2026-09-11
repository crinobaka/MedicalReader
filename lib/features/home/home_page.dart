import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/pages/library_page.dart';
import '../library/providers/library_provider.dart';
import '../library/models/library_document.dart';
import '../reader/pages/reader_annotations_page.dart';
import '../reader/pages/reader_entry_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(libraryProvider);
    final recent = [...documents]..sort((a, b) => _readTime(b).compareTo(_readTime(a)));
    final continueReading = recent.where((d) => _progress(d) > 0).take(6).toList();
    final added = recent.take(8).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('MedicalReader')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(libraryProvider.notifier).reload(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(child: _hero(context, documents.length)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Expanded(child: _action(context, Icons.library_books_outlined, '书库', '管理全部书籍', () => _push(context, const LibraryPage()))),
                  const SizedBox(width: 10),
                  Expanded(child: _action(context, Icons.bookmark_outline, '批注', '高亮、笔记、书签、手绘', () => _push(context, const ReaderAnnotationsPage()))),
                ]),
              ),
            ),
            if (continueReading.isNotEmpty) ...[
              _sectionTitle('继续阅读', '从上次的位置继续', Icons.play_circle_outline),
              _bookSliver(context, continueReading),
            ],
            if (added.isNotEmpty) ...[
              _sectionTitle('最近加入', '${documents.length} 本书籍', Icons.auto_stories_outlined),
              _bookSliver(context, added),
            ],
            if (documents.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('还没有书籍。打开「书库」导入 PDF 或 EPUB 开始阅读。')),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: scheme.primaryContainer, child: Icon(Icons.local_library, size: 30, color: scheme.onPrimaryContainer)),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clinical Knowledge Reader', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(count == 0 ? '建立你的医学阅读工作台' : '你的阅读工作台 · $count 本书', style: Theme.of(context).textTheme.bodyMedium),
          ])),
        ]),
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) =>
      Card(child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis)]))));

  SliverToBoxAdapter _sectionTitle(String title, String subtitle, IconData icon) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Row(children: [
            Icon(icon, size: 21),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)), Text(subtitle, style: const TextStyle(fontSize: 12))])),
          ]),
        ),
      );

  SliverList _bookSliver(BuildContext context, List<LibraryDocument> books) => SliverList.builder(
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          final progress = _progress(book);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 4),
                  Text('${book.format.name.toUpperCase()} · ${book.pages ?? 0} 页'),
                  if (progress > 0) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 2),
                    Text('${(progress * 100).round()}%'),
                  ],
                ]),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, ReaderEntryPage(document: book, initialPage: _page(book))),
              ),
            ),
          );
        },
      );

  static double _progress(LibraryDocument d) {
    final raw = d.metadata['reader_position'];
    if (raw is Map && raw['progress'] is num) return (raw['progress'] as num).clamp(0, 1).toDouble();
    final pages = d.pages ?? 0;
    final page = d.metadata['last_page'];
    if (pages <= 1 || page is! num) return 0;
    return (page / (pages - 1)).clamp(0, 1).toDouble();
  }

  static int _page(LibraryDocument d) {
    final raw = d.metadata['last_page'];
    return raw is num ? raw.toInt().clamp(0, (d.pages ?? 1) - 1) : 0;
  }

  static DateTime _readTime(LibraryDocument d) {
    final raw = d.metadata['last_read_at'];
    return raw is String ? DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0);
  }

  static void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}
