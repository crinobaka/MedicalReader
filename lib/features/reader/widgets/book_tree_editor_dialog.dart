import 'package:flutter/material.dart';

import '../models/book_tree_node.dart';

class BookTreeEditorDialog extends StatefulWidget {
  const BookTreeEditorDialog({super.key, required this.nodes});

  final List<BookTreeNode> nodes;

  @override
  State<BookTreeEditorDialog> createState() => _BookTreeEditorDialogState();
}

class _BookTreeEditorDialogState extends State<BookTreeEditorDialog> {
  late final List<_EditableRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _flatten(widget.nodes);
  }

  List<_EditableRow> _flatten(List<BookTreeNode> nodes) {
    final result = <_EditableRow>[];
    void visit(BookTreeNode node) {
      result.add(_EditableRow.fromNode(node));
      for (final child in node.children) {
        visit(child);
      }
    }
    for (final node in nodes) {
      visit(node);
    }
    return result;
  }

  int? _number(String value) => int.tryParse(value.trim());

  List<BookTreeNode> _result() {
    return List<BookTreeNode>.unmodifiable(
      _rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return BookTreeNode(
          id: row.id.isEmpty
              ? 'edited-${DateTime.now().microsecondsSinceEpoch}-$index'
              : row.id,
          name: row.name.trim(),
          pageStart: _number(row.pdfStart),
          pageEnd: _number(row.pdfEnd),
          bookPageStart: _number(row.bookStart),
          bookPageEnd: _number(row.bookEnd),
        );
      }),
    );
  }

  Widget _field(
    TextEditingController controller, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑目录'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_result()),
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: Text('#')),
                    Expanded(flex: 4, child: Text('标题')),
                    Expanded(child: Text('PDF 起')),
                    Expanded(child: Text('PDF 止')),
                    Expanded(child: Text('书籍起')),
                    Expanded(child: Text('书籍止')),
                    SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return _EditableRowWidget(
                    index: index,
                    row: row,
                    onDelete: () => setState(() => _rows.removeAt(index)),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _rows.add(_EditableRow.empty()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('新增目录项'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableRow {
  _EditableRow({
    required this.id,
    required this.name,
    required this.pdfStart,
    required this.pdfEnd,
    required this.bookStart,
    required this.bookEnd,
  });

  factory _EditableRow.fromNode(BookTreeNode node) => _EditableRow(
        id: node.id,
        name: node.name,
        pdfStart: '${node.pageStart ?? ''}',
        pdfEnd: '${node.pageEnd ?? ''}',
        bookStart: '${node.bookPageStart ?? ''}',
        bookEnd: '${node.bookPageEnd ?? ''}',
      );

  factory _EditableRow.empty() => _EditableRow(
        id: '',
        name: '新目录项',
        pdfStart: '',
        pdfEnd: '',
        bookStart: '',
        bookEnd: '',
      );

  String id;
  String name;
  String pdfStart;
  String pdfEnd;
  String bookStart;
  String bookEnd;
}

class _EditableRowWidget extends StatefulWidget {
  const _EditableRowWidget({
    required this.index,
    required this.row,
    required this.onDelete,
  });

  final int index;
  final _EditableRow row;
  final VoidCallback onDelete;

  @override
  State<_EditableRowWidget> createState() => _EditableRowWidgetState();
}

class _EditableRowWidgetState extends State<_EditableRowWidget> {
  late final TextEditingController _name;
  late final TextEditingController _pdfStart;
  late final TextEditingController _pdfEnd;
  late final TextEditingController _bookStart;
  late final TextEditingController _bookEnd;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.row.name);
    _pdfStart = TextEditingController(text: widget.row.pdfStart);
    _pdfEnd = TextEditingController(text: widget.row.pdfEnd);
    _bookStart = TextEditingController(text: widget.row.bookStart);
    _bookEnd = TextEditingController(text: widget.row.bookEnd);
  }

  @override
  void dispose() {
    _name.dispose();
    _pdfStart.dispose();
    _pdfEnd.dispose();
    _bookStart.dispose();
    _bookEnd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.row.name = _name.text;
    widget.row.pdfStart = _pdfStart.text;
    widget.row.pdfEnd = _pdfEnd.text;
    widget.row.bookStart = _bookStart.text;
    widget.row.bookEnd = _bookEnd.text;

    Widget field(TextEditingController controller, {bool number = false}) {
      return TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text('${widget.index + 1}')),
          Expanded(flex: 4, child: field(_name)),
          const SizedBox(width: 6),
          Expanded(child: field(_pdfStart, number: true)),
          const SizedBox(width: 6),
          Expanded(child: field(_pdfEnd, number: true)),
          const SizedBox(width: 6),
          Expanded(child: field(_bookStart, number: true)),
          const SizedBox(width: 6),
          Expanded(child: field(_bookEnd, number: true)),
          IconButton(
            tooltip: '删除',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
