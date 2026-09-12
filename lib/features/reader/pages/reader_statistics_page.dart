import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../domain/models/reader_statistics.dart';
import '../providers/reader_statistics_provider.dart';

class ReaderStatisticsPage extends ConsumerWidget {
  const ReaderStatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(libraryRepositoryProvider);
    return FutureBuilder<List<LibraryDocument>>(
      future: _loadBooks(repository),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final books = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: const Text('阅读统计')),
          body: books.isEmpty
              ? const Center(child: Text('还没有阅读数据'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(books: books),
                    const SizedBox(height: 16),
                    for (final book in books) _BookStatistics(book: book),
                  ],
                ),
        );
      },
    );
  }

  Future<List<LibraryDocument>> _loadBooks(dynamic repository) async {
    await repository.initialize();
    return repository.getDocuments();
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.books});
  final List<LibraryDocument> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ReaderStatistics>>(
      future: Future.wait(books.map((book) => ref.read(readerStatisticsProvider(book).future))),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const <ReaderStatistics>[];
        final seconds = stats.fold<int>(0, (sum, item) => sum + item.readingTime.inSeconds);
        final characters = stats.fold<int>(0, (sum, item) => sum + item.charactersRead);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Metric(label: '书籍', value: '${books.length}'),
                _Metric(label: '阅读时长', value: _duration(seconds)),
                _Metric(label: '字符', value: _compact(characters)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  String _compact(int value) => value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : '$value';
}

class _BookStatistics extends ConsumerWidget {
  const _BookStatistics({required this.book});
  final LibraryDocument book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(readerStatisticsProvider(book));
    return async.when(
      loading: () => const ListTile(title: Text('加载中…')),
      error: (_, _) => ListTile(title: Text(book.title), subtitle: const Text('统计不可用')),
      data: (stats) => Card(
        child: ListTile(
          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${stats.sessions} 次会话 · ${stats.charactersRead} 字符 · ${stats.charactersPerMinute.toStringAsFixed(0)} 字/分'),
          trailing: Text('${stats.readingTime.inMinutes} 分钟'),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label),
        ],
      );
}
