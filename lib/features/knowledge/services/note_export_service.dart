import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/note_document.dart';

/// Exports a note independently from its source book.
/// The exported document intentionally contains no LibraryDocument reference.
class NoteExportService {
  const NoteExportService();

  String toMarkdown(NoteDocument note) {
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    return '# $title\n\n${note.body}\n';
  }

  Future<String?> exportMarkdown(NoteDocument note) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出 Markdown 笔记',
      fileName: '${_safeName(note.title)}.md',
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (path == null) return null;
    await File(path).writeAsString(toMarkdown(note));
    return path;
  }

  Future<String?> exportPdf(NoteDocument note) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出 PDF 笔记',
      fileName: '${_safeName(note.title)}.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null) return null;
    final document = pw.Document();
    document.addPage(pw.MultiPage(
      build: (_) => [
        pw.Header(level: 0, text: note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim()),
        pw.Paragraph(text: note.body),
      ],
    ));
    await File(path).writeAsBytes(await document.save());
    return path;
  }

  String _safeName(String value) {
    final name = value.trim().isEmpty ? 'note' : value.trim();
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
