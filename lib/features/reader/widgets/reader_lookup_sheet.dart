import 'package:flutter/material.dart';

import '../domain/models/reader_lookup.dart';
import '../domain/models/reader_mining.dart';
import '../domain/services/reader_dictionary_service.dart';

class ReaderLookupSheet extends StatefulWidget {
  const ReaderLookupSheet({super.key, required this.contextData, required this.dictionary});
  final ReaderLookupContext contextData;
  final ReaderDictionaryRegistry dictionary;

  @override
  State<ReaderLookupSheet> createState() => _ReaderLookupSheetState();
}

class _ReaderLookupSheetState extends State<ReaderLookupSheet> {
  late Future<List<DictionaryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.dictionary.lookup(widget.contextData.toRequest());
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: FutureBuilder<List<DictionaryEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _error(snapshot.error!);
              if (!snapshot.hasData) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
              final entries = snapshot.data!;
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(widget.contextData.selectedText, style: Theme.of(context).textTheme.headlineSmall)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                if (widget.contextData.sentence.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.contextData.sentence)),
                if (entries.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 36), child: Center(child: Text('暂无词典结果，可在设置中连接词典服务。')))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, index) {
                        final entry = entries[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.headword),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (entry.reading.isNotEmpty) Text(entry.reading),
                            Text(entry.definition),
                            if (entry.tags.isNotEmpty) Text(entry.tags.join(' · ')),
                          ]),
                          trailing: IconButton(
                            tooltip: '挖词到 Anki',
                            icon: const Icon(Icons.style_outlined),
                            onPressed: () => Navigator.pop(context, entry),
                          ),
                        );
                      },
                    ),
                  ),
              ]);
            },
          ),
        ),
      );

  Widget _error(Object error) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 8),
          const Text('词典查询失败'),
          const SizedBox(height: 4),
          Text('$error', textAlign: TextAlign.center),
        ]),
      );
}
