import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PageJumpDialog extends StatefulWidget {
  const PageJumpDialog({super.key, required this.currentPage, required this.pageCount});
  final int currentPage;
  final int pageCount;

  @override
  State<PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<PageJumpDialog> {
  late final TextEditingController _controller = TextEditingController(text: '${widget.currentPage}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text);
    if (value != null && value >= 1 && value <= widget.pageCount) {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('跳转到页码'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: '1 - ${widget.pageCount}',
          suffixText: '/ ${widget.pageCount}',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('跳转')),
      ],
    );
  }
}

class BookPageJumpDialog extends StatefulWidget {
  const BookPageJumpDialog({super.key, required this.currentPage});
  final int? currentPage;

  @override
  State<BookPageJumpDialog> createState() => _BookPageJumpDialogState();
}

class _BookPageJumpDialogState extends State<BookPageJumpDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentPage?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value != null && value > 0) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('跳转到书籍页码'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '书籍页码'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('跳转')),
      ],
    );
  }
}
