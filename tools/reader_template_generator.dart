import 'dart:convert';
import 'dart:io';

/// Console template generator for a text-adventure style workflow.
/// Run: dart run tools/reader_template_generator.dart [output.json]
Future<void> main(List<String> args) async {
  stdout.writeln('MedicalReader · Template Adventure');
  stdout.writeln('像创建一本书的角色卡一样回答几个问题。');
  final id = _ask('模板 ID', 'my-book');
  final name = _ask('模板名称', 'My Medical Book');
  final description = _ask('一句话描述', 'Generated reader template');
  final aliases = _ask('书名匹配别名（逗号分隔，可空）', '');
  final pageOffset = int.tryParse(_ask('PDF 到书籍页码偏移（PDF - offset = book）', '0')) ?? 0;
  final cropMode = _ask('默认裁剪：none / double / triple', 'none');
  final searchPrefix = _ask('搜索上下文前缀（可空）', '');

  final json = <String, dynamic>{
    'id': id,
    'name': name,
    'version': '1.0.0',
    'description': description,
    'author': Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? 'local',
    'data': {
      'aliases': aliases.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'metadata': {'title': name},
      'defaults': {
        'bookPageMapping': {'mode': 'offset', 'offset': pageOffset},
        'searchContext': {'prefix': searchPrefix},
        'crop': {'mode': cropMode},
      },
    },
  };

  final output = args.isEmpty ? 'reader_template.json' : args.first;
  await File(output).writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  stdout.writeln('模板已生成：$output');
}

String _ask(String label, String fallback) {
  stdout.write('$label [$fallback]: ');
  final value = stdin.readLineSync()?.trim();
  return value == null || value.isEmpty ? fallback : value;
}
