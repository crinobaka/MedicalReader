import 'package:flutter/material.dart';

import '../models/book_tree_node.dart';

/// Spreadsheet-like outline editor. Rows retain their original depth so
/// editing titles/pages never destroys the PDF outline hierarchy.
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
    void visit(BookTreeNode node, int depth) {
      result.add(_EditableRow.fromNode(node, depth));
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }
    for (final node in nodes) {
      visit(node, 0);
    }
    return result;
  }

  int? _number(String value) => int.tryParse(value.trim());

  List<BookTreeNode> _result() {
    final roots = <BookTreeNode>[];
    final stack = <BookTreeNode>[];

    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      final node = BookTreeNode(
        id: row.id.isEmpty
            ? 'edited-${DateTime.now().microsecondsSinceEpoch}-$index'
            : row.id,
        name: row.name.trim(),
        pageStart: _number(row.pdfStart),
        pageEnd: _number(row.pdfEnd),
        bookPageStart: _number(row.bookStart),
        bookPageEnd: _number(row.bookEnd),
      );

      final depth = row.depth.clamp(0, stack.length).toInt();
      if (depth == 0) {
        roots.add(node);
      } else {
        final parent = stack[depth - 1];
        final children = [...parent.children, node];
        stack[depth - 1] = BookTreeNode(
          id: parent.id,
          name: parent.name,
          pageStart: parent.pageStart,
          pageEnd: parent.pageEnd,
          bookPageStart: parent.bookPageStart,
          bookPageEnd: parent.bookPageEnd,
          children: List.unmodifiable(children),
        );
        // Rebuild ancestors after replacing the parent.
        for (var ancestorDepth = depth - 2; ancestorDepth >= 0; ancestorDepth--) {
          final ancestor = stack[ancestorDepth];
          final child = stack[ancestorDepth + 1];
          final replacedChildren = ancestor.children
              .map((item) => item.id == child.id ? child : item)
              .toList(growable: false);
          stack[ancestorDepth] = BookTreeNode(
            id: ancestor.id,
            name: ancestor.name,
            pageStart: ancestor.pageStart,
            pageEnd: ancestor.pageEnd,
            bookPageStart: ancestor.bookPageStart,
            bookPageEnd: ancestor.bookPageEnd,
            children: replacedChildren,
          );
        }
      }

      if (row.depth == 0) {
        stack
          ..clear()
          ..add(node);
      } else {
        if (stack.length > row.depth) {
          stack[row.depth] = node;
          stack.removeRange(row.depth + 1, stack.length);
        } else {
          stack.add(node);
        }
      }

      // The stack contains the logical path. Roots need the final updated node
      // when a child is appended; the next pass fixes ancestors in place.
      if (depth > 0) {
        final updatedRoot = _replaceInTree(roots, stack.first);
        roots
          ..clear()
          ..addAll(updatedRoot);
      }
    }
    return List<BookTreeNode>.unmodifiable(roots);
  }

  List<BookTreeNode> _replaceInTree(List<BookTreeNode> roots, BookTreeNode replacement) {
    return roots.map((root) {
      if (root.id == replacement.id) return replacement;
      final children = _replaceInTree(root.children, replacement);
      if (children.length == root.children.length &&
          List.generate(children.length, (i) => identical(children[i], root.children[i]))
              .every((value) => value)) {
        return root;
      }
      return BookTreeNode(
        id: root.id,
        name: root.name,
        pageStart: root.pageStart,
        pageEnd: root.pageEnd,
        bookPageStart: root.bookPageStart,
        bookPageEnd: root.bookPageEnd,
        children: children,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑目录'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
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
                child: Row(children: [
                  SizedBox(width: 44, child: Text('#')),
                  SizedBox(width: 82, child: Text('层级')),
                  Expanded(flex: 4, child: Text('标题')),
                  Expanded(child: Text('PDF 起')),
                  Expanded(child: Text('PDF 止')),
                  Expanded(child: Text('书籍起')),
                  Expanded(child: Text('书籍止')),
                  SizedBox(width: 48),
                ]),
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
                    canIndent: index > 0,
                    onIndent: () => setState(() {
                      row.depth = (row.depth + 1).clamp(0, 8).toInt();
                    }),
                    onOutdent: () => setState(() {
                      row.depth = (row.depth - 1).clamp(0, 8).toInt();
                    }),
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
                    onPressed: () => setState(() => _rows.add(_EditableRow.empty())),
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
    required this.depth,
  });

  factory _EditableRow.fromNode(BookTreeNode node, int depth) => _EditableRow(
        id: node.id,
        name: node.name,
        pdfStart: '${node.pageStart ?? ''}',
        pdfEnd: '${node.pageEnd ?? ''}',
        bookStart: '${node.bookPageStart ?? ''}',
        bookEnd: '${node.bookPageEnd ?? ''}',
        depth: depth,
      );

  factory _EditableRow.empty() => _EditableRow(
        id: '', name: '新目录项', pdfStart: '', pdfEnd: '', bookStart: '', bookEnd: '', depth: 0,
      );

  String id;
  String name;
  String pdfStart;
  String pdfEnd;
  String bookStart;
  String bookEnd;
  int depth;
}

class _EditableRowWidget extends StatefulWidget {
  const _EditableRowWidget({
    required this.index,
    required this.row,
    required this.canIndent,
    required this.onIndent,
    required this.onOutdent,
    required this.onDelete,
  });

  final int index;
  final _EditableRow row;
  final bool canIndent;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
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

  Widget _field(TextEditingController controller, {bool number = false}) => TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    widget.row.name = _name.text;
    widget.row.pdfStart = _pdfStart.text;
    widget.row.pdfEnd = _pdfEnd.text;
    widget.row.bookStart = _bookStart.text;
    widget.row.bookEnd = _bookEnd.text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text('${widget.index + 1}')),
          SizedBox(
            width: 82,
            child: Row(children: [
              IconButton(
                tooltip: '减少层级',
                onPressed: widget.row.depth > 0 ? widget.onOutdent : null,
                icon: const Icon(Icons.format_indent_decrease, size: 18),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                tooltip: '增加层级',
                onPressed: widget.canIndent ? widget.onIndent : null,
                icon: const Icon(Icons.format_indent_increase, size: 18),
                padding: EdgeInsets.zero,
              ),
            ]),
          ),
          Expanded(flex: 4, child: Padding(padding: const EdgeInsets.only(left: 4), child: _field(_name))),
          const SizedBox(width: 6),
          Expanded(child: _field(_pdfStart, number: true)),
          const SizedBox(width: 6),
          Expanded(child: _field(_pdfEnd, number: true)),
          const SizedBox(width: 6),
          Expanded(child: _field(_bookStart, number: true)),
          const SizedBox(width: 6),
          Expanded(child: _field(_bookEnd, number: true)),
          IconButton(tooltip: '删除', onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}
