import 'package:flutter/material.dart';

import '../domain/models/reader_mining.dart';

class ReaderMiningSheet extends StatefulWidget {
  const ReaderMiningSheet({super.key, required this.entry, required this.onMine});
  final DictionaryEntry entry;
  final Future<bool> Function(AnkiCardDraft draft) onMine;

  @override
  State<ReaderMiningSheet> createState() => _ReaderMiningSheetState();
}

class _ReaderMiningSheetState extends State<ReaderMiningSheet> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.entry.headword);
    _back = TextEditingController(text: widget.entry.definition);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [Expanded(child: Text('挖词到 Anki', style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
            TextField(controller: _front, decoration: const InputDecoration(labelText: '正面')),
            const SizedBox(height: 10),
            TextField(controller: _back, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '背面')),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: const Text('发送到 Anki'),
            ),
          ]),
        ),
      );

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await widget.onMine(AnkiCardDraft(front: _front.text.trim(), back: _back.text.trim(), tags: widget.entry.tags));
    if (!mounted) return;
    if (ok) Navigator.pop(context, true);
    else setState(() => _busy = false);
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }
}
