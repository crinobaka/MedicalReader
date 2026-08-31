import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../library/models/library_document.dart';
import '../../reader/models/reader_annotation.dart';
import '../../reader/pages/reader_page.dart';
import '../../reader/providers/reader_annotation_provider.dart';
import '../../reader/services/reader_annotation_service.dart';
import '../models/note_document.dart';
import '../models/note_drawing.dart';
import '../services/detached_note_storage.dart';
import '../services/note_drawing_storage.dart';
import '../services/note_export_service.dart';
import '../widgets/note_content_preview.dart';
import '../widgets/note_drawing_editor.dart';

class KnowledgeNotePage extends ConsumerStatefulWidget {
  final LibraryDocument? document;
  final ReaderAnnotation? note;
  final NoteDocument? detachedNote;
  const KnowledgeNotePage({
    super.key,
    this.document,
    this.note,
    this.detachedNote,
  }) : assert(note != null || detachedNote != null);
  bool get isDetached =>
      detachedNote != null || document == null || note == null;
  @override
  ConsumerState<KnowledgeNotePage> createState() => _KnowledgeNotePageState();
}

class _KnowledgeNotePageState extends ConsumerState<KnowledgeNotePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final AudioRecorder _audioRecorder;
  late ReaderNoteFormat _noteFormat;
  late List<String> _attachments;
  bool _previewMode = false;
  bool _saving = false;
  bool _recording = false;
  String? _recordingPath;
  bool get _detached => widget.isDetached;

  @override
  void initState() {
    super.initState();
    final source = widget.detachedNote;
    _titleController = TextEditingController(
      text: source?.title ?? widget.note!.title,
    );
    _contentController = TextEditingController(
      text: source?.body ?? widget.note!.content,
    );
    _noteFormat = source?.format ?? widget.note!.noteFormat;
    _attachments = [...(source?.attachments ?? widget.note!.attachments)];
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  NoteDocument get _draft => widget.detachedNote == null
      ? NoteDocument(
          id: widget.note!.id,
          bookId: widget.note!.bookId,
          pageIndex: widget.note!.pageIndex,
          title: _titleController.text.trim(),
          body: _contentController.text,
          format: _noteFormat,
          attachments: List.unmodifiable(_attachments),
          createdAt: widget.note!.createdAt,
          updatedAt: DateTime.now(),
        )
      : NoteDocument(
          id: widget.detachedNote!.id,
          title: _titleController.text.trim(),
          body: _contentController.text,
          format: _noteFormat,
          attachments: List.unmodifiable(_attachments),
          createdAt: widget.detachedNote!.createdAt,
          updatedAt: DateTime.now(),
        );

  Future<void> _save() async {
    if (_saving || _recording) return;
    setState(() => _saving = true);
    try {
      if (_detached) {
        await const DetachedNoteStorage().save(_draft.detach());
      } else {
        final updated = widget.note!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text,
          noteFormat: _noteFormat,
          attachments: List.unmodifiable(_attachments),
          updatedAt: DateTime.now(),
        );
        await ref
            .read(readerAnnotationsProvider(widget.document!).notifier)
            .add(updated);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> get _drawingAttachments => _attachments
      .where(
        (path) =>
            path.toLowerCase().endsWith('.json') &&
            path.contains(
              '${Platform.pathSeparator}note_drawings${Platform.pathSeparator}',
            ),
      )
      .toList();

  Future<void> _editDrawing() async {
    if (_previewMode || _saving || _recording) return;
    NoteDrawingLayer? initial;
    String? previousPath;
    final drawings = _drawingAttachments;
    if (drawings.isNotEmpty) {
      previousPath = drawings.last;
      try {
        initial = await const NoteDrawingStorage().load(previousPath);
      } catch (_) {
        previousPath = null;
      }
    }
    if (!mounted) return;
    final layer = await Navigator.of(context).push<NoteDrawingLayer>(
      MaterialPageRoute(
        builder: (_) => NoteDrawingEditor(initialLayer: initial),
      ),
    );
    if (layer == null || !mounted) return;
    if (layer.strokes.isEmpty) {
      if (previousPath != null)
        setState(() => _attachments.remove(previousPath));
      return;
    }
    try {
      final path = await const NoteDrawingStorage().save(_draft.id, layer);
      setState(() {
        if (previousPath != null) {
          final index = _attachments.indexOf(previousPath);
          if (index >= 0) _attachments[index] = path;
        } else {
          _attachments.add(path);
        }
      });
      _showMessage('手绘已保存，可再次打开继续编辑');
    } catch (error) {
      _showMessage('保存手绘失败：$error');
    }
  }

  Future<void> _detach() async {
    if (_detached || _saving || _recording) return;
    final detached = _draft.detach();
    await const DetachedNoteStorage().save(detached);
    await ref
        .read(readerAnnotationsProvider(widget.document!).notifier)
        .remove(widget.note!.id);
    if (mounted)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => KnowledgeNotePage(detachedNote: detached),
        ),
      );
  }

  Future<void> _export() async {
    if (_saving || _recording) return;
    final note = _draft;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('导出 Markdown'),
              onTap: () => Navigator.pop(context, 'md'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('导出 PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final service = const NoteExportService();
    final path = choice == 'md'
        ? await service.exportMarkdown(note)
        : await service.exportPdf(note);
    if (mounted && path != null)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导出：$path')));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定删除这条笔记吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_detached)
      await const DetachedNoteStorage().delete(_draft.id);
    else
      await ref
          .read(readerAnnotationsProvider(widget.document!).notifier)
          .remove(widget.note!.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _openPdf() {
    if (_detached) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          document: widget.document!,
          initialPage: widget.note!.pageIndex,
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    if (_previewMode || _saving || _recording || _detached) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return _showMessage('没有检测到可用摄像头');
      if (!mounted) return;
      final result = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => _CameraCapturePage(camera: cameras.first),
        ),
      );
      if (result == null) return;
      final reference = await const ReaderAnnotationService()
          .importAttachmentReference(widget.document!, result.path);
      setState(() {
        _attachments = [..._attachments, reference];
        final separator = _contentController.text.isEmpty ? '' : '\n\n';
        _contentController.text =
            '${_contentController.text}$separator![图片]($reference)';
      });
    } catch (error) {
      _showMessage('拍照失败：$error');
    }
  }

  Future<void> _toggleRecording() async {
    if (_previewMode || _saving || _detached) return;
    if (_recording) return _stopRecording();
    try {
      if (!await _audioRecorder.hasPermission()) return _showMessage('没有录音权限');
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}${Platform.pathSeparator}medicalreader_recording_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      if (mounted)
        setState(() {
          _recording = true;
          _recordingPath = path;
        });
    } catch (error) {
      _showMessage('开始录音失败：$error');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final temporaryPath = await _audioRecorder.stop();
      if (mounted) setState(() => _recording = false);
      final source = temporaryPath ?? _recordingPath;
      _recordingPath = null;
      if (source == null) return _showMessage('录音文件不存在');
      final reference = await const ReaderAnnotationService()
          .importAttachmentReference(widget.document!, source);
      setState(() => _attachments = [..._attachments, reference]);
      try {
        await File(source).delete();
      } catch (_) {}
    } catch (error) {
      if (mounted) setState(() => _recording = false);
      _showMessage('停止录音失败：$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final attachmentDirectory = !_detached && widget.document != null
        ? File(widget.document!.file.path).parent.path
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_detached ? '独立笔记' : '笔记'),
        actions: [
          IconButton(
            tooltip: _previewMode ? '编辑' : '预览',
            icon: Icon(
              _previewMode ? Icons.edit_outlined : Icons.preview_outlined,
            ),
            onPressed: _recording
                ? null
                : () => setState(() => _previewMode = !_previewMode),
          ),
          IconButton(
            tooltip: '导出',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _recording ? null : _export,
          ),
          if (!_detached)
            IconButton(
              tooltip: '与书籍解绑',
              icon: const Icon(Icons.link_off_outlined),
              onPressed: _recording ? null : _detach,
            ),
          if (!_detached)
            IconButton(
              tooltip: '定位 PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _recording ? null : _openPdf,
            ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: _recording ? null : _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _titleController,
              enabled: !_previewMode && !_recording,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _detached ? '独立笔记' : widget.document!.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_detached) Text('第 ${widget.note!.pageIndex + 1} 页'),
                const SizedBox(width: 8),
                DropdownButton<ReaderNoteFormat>(
                  value: _noteFormat,
                  onChanged: _previewMode || _recording
                      ? null
                      : (value) {
                          if (value != null)
                            setState(() => _noteFormat = value);
                        },
                  items: const [
                    DropdownMenuItem(
                      value: ReaderNoteFormat.markdown,
                      child: Text('Markdown'),
                    ),
                    DropdownMenuItem(
                      value: ReaderNoteFormat.markdownHtml,
                      child: Text('Markdown-HTML'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _previewMode
                ? NoteContentPreview(
                    note: _draft,
                    attachmentBasePath: attachmentDirectory == null
                        ? null
                        : '$attachmentDirectory${Platform.pathSeparator}attachments',
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: '在这里编写笔记...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
          ),
          if (!_previewMode)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving || _recording ? null : _editDrawing,
                        icon: const Icon(Icons.draw_outlined),
                        label: Text(
                          _drawingAttachments.isEmpty ? '手绘' : '编辑手绘',
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_detached)
                        OutlinedButton.icon(
                          onPressed: _saving || _recording ? null : _takePhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('拍照'),
                        ),
                      if (!_detached) const SizedBox(width: 8),
                      if (!_detached)
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _toggleRecording,
                          icon: Icon(
                            _recording
                                ? Icons.stop_circle_outlined
                                : Icons.mic_none_outlined,
                          ),
                          label: Text(_recording ? '停止录音' : '录音'),
                        ),
                      if (_recording)
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text('正在录音...'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || _recording ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中...' : '保存笔记'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCapturePage extends StatefulWidget {
  final CameraDescription camera;
  const _CameraCapturePage({required this.camera});
  @override
  State<_CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<_CameraCapturePage> {
  late final CameraController _controller;
  late final Future<void> _initializeFuture;
  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      final file = await _controller.takePicture();
      if (mounted) Navigator.of(context).pop(file);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('拍照失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('拍照')),
    body: FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('摄像头初始化失败：${snapshot.error}'));
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(child: CameraPreview(_controller)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FloatingActionButton(
                onPressed: _capture,
                child: const Icon(Icons.camera_alt),
              ),
            ),
          ],
        );
      },
    ),
  );
}
