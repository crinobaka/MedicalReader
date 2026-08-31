import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/widgets.dart' as pw;

import '../models/note_document.dart';
import '../../reader/models/reader_annotation.dart';

/// Exports a note independently from its source book.
/// Attachments remain explicit resources instead of being embedded in Markdown.
class NoteExportService {
  const NoteExportService();

  String toMarkdown(NoteDocument note) {
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    final attachmentText = _attachmentsMarkdown(note);
    if (note.format == ReaderNoteFormat.markdownHtml) {
      return '<h1>${_escapeHtml(title)}</h1>\n\n${note.body}\n$attachmentText';
    }
    return '# $title\n\n${note.body}\n$attachmentText';
  }

  String toHtml(NoteDocument note) {
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    final body = note.format == ReaderNoteFormat.markdownHtml
        ? note.body
        : md.markdownToHtml(note.body, extensionSet: md.ExtensionSet.gitHubFlavored);
    final attachments = note.attachments.isEmpty
        ? ''
        : '<section><h2>Attachments</h2><ul>${note.attachments.map((path) => '<li><a href="${_escapeHtml(_fileUri(path))}">${_escapeHtml(_basename(path))}</a></li>').join()}</ul></section>';
    return '<!doctype html><html><head><meta charset="utf-8"><title>${_escapeHtml(title)}</title><style>pre{padding:12px;overflow:auto;background:#f4f4f4;border-radius:8px;}code{font-family:monospace;}</style></head><body><h1>${_escapeHtml(title)}</h1>$body$attachments</body></html>';
  }

  Future<String?> exportMarkdown(NoteDocument note) async {
    final bytes = utf8.encode(note.format == ReaderNoteFormat.markdownHtml ? toHtml(note) : toMarkdown(note));
    return (await FilePicker.saveFile(dialogTitle: '导出 Markdown 笔记', fileName: '${_safeName(note.title)}.${note.format == ReaderNoteFormat.markdownHtml ? 'html' : 'md'}', type: FileType.custom, allowedExtensions: note.format == ReaderNoteFormat.markdownHtml ? const ['html'] : const ['md'], bytes: bytes))?.toFilePath();
  }

  Future<String?> exportPdf(NoteDocument note) async {
    final document = pw.Document();
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    document.addPage(pw.MultiPage(build: (_) => [
      pw.Header(level: 0, text: title),
      pw.Paragraph(text: _plainText(note)),
      if (note.attachments.isNotEmpty) pw.Header(level: 1, text: 'Attachments'),
      ...note.attachments.map((path) => pw.Bullet(text: _basename(path))),
    ]));
    final bytes = await document.save();
    return (await FilePicker.saveFile(dialogTitle: '导出 PDF 笔记', fileName: '${_safeName(note.title)}.pdf', type: FileType.custom, allowedExtensions: const ['pdf'], bytes: bytes))?.toFilePath();
  }

  String _plainText(NoteDocument note) {
    if (note.format == ReaderNoteFormat.markdown) return note.body.replaceAll(RegExp(r'[`*_#>\[\]()]'), '');
    return note.body.replaceAll(RegExp(r'<[^>]*>'), ' ');
  }

  String _attachmentsMarkdown(NoteDocument note) {
    if (note.attachments.isEmpty) return '';
    final lines = note.attachments.map((path) => '- [${_basename(path)}](${_fileUri(path)})').join('\n');
    return '\n\n## Attachments\n$lines\n';
  }

  String _fileUri(String path) => 'file:///${path.replaceAll('\\', '/')}';
  String _basename(String path) => path.split(RegExp(r'[\\/]')).last;
  String _escapeHtml(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  String _safeName(String value) => (value.trim().isEmpty ? 'note' : value.trim()).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
