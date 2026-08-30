import 'package:flutter/material.dart';
import '../models/book_tree_node.dart';

class BookTreeEditorDialog extends StatefulWidget {
  final List<BookTreeNode> nodes;
  const BookTreeEditorDialog({super.key, required this.nodes});
  @override
  State<BookTreeEditorDialog> createState() => _BookTreeEditorDialogState();
}

class _Row {
  final String id;
  String name, start, end, bookStart, bookEnd;
  _Row(this.id, this.name, this.start, this.end, this.bookStart, this.bookEnd);
}

class _BookTreeEditorDialogState extends State<BookTreeEditorDialog> {
  late final List<_Row> _rows;

  @override
  void initState() { super.initState(); _rows = _flatten(widget.nodes); }

  List<_Row> _flatten(List<BookTreeNode> nodes) {
    final out = <_Row>[];
    void visit(BookTreeNode node) {
      out.add(_Row(node.id, node.name, '${node.pageStart ?? ''}', '${node.pageEnd ?? ''}', '${node.bookPageStart ?? ''}', '${node.bookPageEnd ?? ''}'));
      for (final child in node.children) visit(child);
    }
    for (final node in nodes) visit(node);
    return out;
  }

  int? _number(String value) => int.tryParse(value.trim());

  List<BookTreeNode> _result() => List.unmodifiable(_rows.asMap().entries.map((entry) {
    final r = entry.value;
    return BookTreeNode(id: r.id.isEmpty ? 'edited-${DateTime.now().microsecondsSinceEpoch}-$entry' : r.id, name: r.name.trim(), pageStart: _number(r.start), pageEnd: _number(r.end), bookPageStart: _number(r.bookStart), bookPageEnd: _number(r.bookEnd));
  }));

  Widget _field(String value, ValueChanged<String> onChanged, {bool number = false}) => TextField(controller: TextEditingController(text: value), onChanged: onChanged, keyboardType: number ? TextInputType.number : TextInputType.text, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)));

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(child: Scaffold(
    appBar: AppBar(title: const Text('编辑目录'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), const SizedBox(width: 8), FilledButton.icon(onPressed: () => Navigator.pop(context, _result()), icon: const Icon(Icons.save_outlined), label: const Text('保存'))]),
    body: Column(children: [
      Material(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [SizedBox(width: 44, child: Text('#')), Expanded(flex: 4, child: Text('标题')), Expanded(child: Text('PDF 起')), Expanded(child: Text('PDF 止')), Expanded(child: Text('书籍起')), Expanded(child: Text('书籍止')), SizedBox(width: 48)]))),
      Expanded(child: ListView.builder(itemCount: _rows.length, itemBuilder: (context, index) { final r = _rows[index]; return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Row(children: [SizedBox(width: 44, child: Text('${index + 1}')), Expanded(flex: 4, child: _field(r.name, (v) => r.name = v)), const SizedBox(width: 6), Expanded(child: _field(r.start, (v) => r.start = v, number: true)), const SizedBox(width: 6), Expanded(child: _field(r.end, (v) => r.end = v, number: true)), const SizedBox(width: 6), Expanded(child: _field(r.bookStart, (v) => r.bookStart = v, number: true)), const SizedBox(width: 6), Expanded(child: _field(r.bookEnd, (v) => r.bookEnd = v, number: true)), IconButton(tooltip: '删除', onPressed: () => setState(() => _rows.removeAt(index)), icon: const Icon(Icons.delete_outline))])); })),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => setState(() => _rows.add(_Row('', '新目录项', '', '', '', ''))), icon: const Icon(Icons.add), label: const Text('新增目录项')))),
    ]),
  ));
}
