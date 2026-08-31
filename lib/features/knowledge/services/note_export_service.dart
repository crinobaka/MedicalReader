import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/widgets.dart' as pw;

import '../models/note_document.dart';
import '../../reader/models/reader_annotation.dart';

/// Exports a note independently from its source book.
/// Exported content never requires the originating LibraryDocument.
class NoteExportService {
  const NoteExportService();

  String toMarkdown(NoteDocument note) {
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    if (note.format == ReaderNoteFormat.markdownHtml) {
      return '<h1>${_escapeHtml(title)}</h1>\n\n${note.body}\n';
    }
    return '# $title\n\n${note.body}\n';
  }

  /// Returns the actual HTML document for either Markdown or HTML notes.
  String toHtml(NoteDocument note) {
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    final body = note.format == ReaderNoteFormat.markdownHtml
        ? note.body
        : md.markdownToHtml(note.body, extensionSet: md.ExtensionSet.gitHubFlavored);
    return '<!doctype html><html><head><meta charset="utf-8"><title>${_escapeHtml(title)}</title></head><body><h1>${_escapeHtml(title)}</h1>$body</body></html>';
  }

  Future<String?> exportMarkdown(NoteDocument note) async {
    final bytes = utf8.encode(note.format == ReaderNoteFormat.markdownHtml ? toHtml(note) : toMarkdown(note));
    return (await FilePicker.saveFile(
      dialogTitle: '导出 Markdown 笔记',
      fileName: '${_safeName(note.title)}.${note.format == ReaderNoteFormat.markdownHtml ? 'html' : 'md'}',
      type: FileType.custom,
      allowedExtensions: note.format == ReaderNoteFormat.markdownHtml ? const ['html'] : const ['md'],
      bytes: bytes,
    ))?.toFilePath();
  }

  Future<String?> exportPdf(NoteDocument note) async {
    final document = pw.Document();
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, text: title),
          pw.Paragraph(text: _plainText(note)),
        ],
      ),
    );
    final bytes = await document.save();
    return (await FilePicker.saveFile(
      dialogTitle: '导出 PDF 笔记',
      fileName: '${_safeName(note.title)}.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    ))?.toFilePath();
  }

  String _plainText(NoteDocument note) {
    if (note.format == ReaderNoteFormat.markdown) {
      return note.body.replaceAll(RegExp(r'[`*_#>\[\]()]'), '');
    }
    return note.body.replaceAll(RegExp(r'<[^>]*>'), ' ');
  }

  String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _safeName(String value) {
    final name = value.trim().isEmpty ? 'note' : value.trim();
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
