import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note_drawing.dart';

class NoteDrawingStorage {
  const NoteDrawingStorage();

  Future<Directory> _directory(String noteId) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}note_drawings${Platform.pathSeparator}${_safe(noteId)}');
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> save(String noteId, NoteDrawingLayer layer) async {
    final dir = await _directory(noteId);
    final file = File('${dir.path}${Platform.pathSeparator}drawing_${DateTime.now().microsecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(layer.toJson()));
    return file.path;
  }

  Future<NoteDrawingLayer> load(String path) async {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map) throw const FormatException('Invalid drawing resource');
    return NoteDrawingLayer.fromJson(Map<String, dynamic>.from(decoded));
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
