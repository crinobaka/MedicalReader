import 'dart:convert';
import 'dart:io';

/// Converts an indented plain-text outline into book.json.
/// Two spaces per level. Metadata: {pdf=1-20,book=1-18}.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法：dart run tools/directory_generator.dart outline.txt [book.json]');
    exitCode = 2;
    return;
  }
  final input = await File(args.first).readAsString();
  final roots = <Map<String, dynamic>>[];
  final stack = <({int level, Map<String, dynamic> node})>[];
  var id = 0;

  for (final raw in input.split(RegExp(r'\r?\n'))) {
    if (raw.trim().isEmpty || raw.trimLeft().startsWith('#')) continue;
    final leading = raw.length - raw.trimLeft().length;
    if (leading % 2 != 0) throw FormatException('缩进必须使用 2 个空格：$raw');
    final level = leading ~/ 2;
    final parsed = _parse(raw.trim(), 'node_${++id}');
    while (stack.isNotEmpty && stack.last.level >= level) stack.removeLast();
    if (stack.isEmpty) {
      roots.add(parsed);
    } else {
      (stack.last.node['children'] as List<dynamic>).add(parsed);
    }
    stack.add((level: level, node: parsed));
  }

  final output = args.length > 1 ? args[1] : 'book.json';
  final json = {'version': 1, 'bookTree': roots};
  await File(output).writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  stdout.writeln('目录已生成：$output');
}

Map<String, dynamic> _parse(String line, String id) {
  final match = RegExp(r'^(.*?)(?:\s*\{([^}]*)\})?$').firstMatch(line)!;
  final node = <String, dynamic>{'id': id, 'name': match.group(1)!.trim(), 'children': <dynamic>[]};
  final metadata = match.group(2);
  if (metadata == null) return node;
  for (final item in metadata.split(',')) {
    final parts = item.split('=').map((e) => e.trim()).toList();
    if (parts.length != 2) continue;
    final values = parts[1].split('-').map(int.tryParse).toList();
    if (values.isEmpty || values.first == null) continue;
    final start = values.first!;
    final end = values.length > 1 && values[1] != null ? values[1]! : start;
    if (parts[0] == 'pdf') {
      node['page_start'] = start;
      node['page_end'] = end;
    } else if (parts[0] == 'book') {
      node['book_page_start'] = start;
      node['book_page_end'] = end;
    }
  }
  return node;
}
