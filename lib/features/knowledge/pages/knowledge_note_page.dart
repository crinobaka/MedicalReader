import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../library/models/library_document.dart';
import '../../reader/models/reader_annotation.dart';
import '../../reader/pages/reader_page.dart';
import '../../reader/providers/reader_annotation_provider.dart';
import '../../reader/services/reader_annotation_service.dart';

/// Knowledge 中单条 Note 的详情页。
///
/// 这里负责：
///
/// - Note 标题编辑
/// - Markdown / Markdown + HTML 正文编辑
/// - Markdown 预览
/// - 拍照插入图片
/// - 录音插入音频
/// - 保存
/// - 删除
/// - 回到 PDF 对应页
///
/// 注意：
///
/// Note 仍然使用 ReaderAnnotation。
/// Knowledge 不建立第二套 Note 数据库。
class KnowledgeNotePage extends ConsumerStatefulWidget {
  final LibraryDocument document;
  final ReaderAnnotation note;

  const KnowledgeNotePage({
    super.key,
    required this.document,
    required this.note,
  });

  @override
  ConsumerState<KnowledgeNotePage> createState() =>
      _KnowledgeNotePageState();
}

class _KnowledgeNotePageState
    extends ConsumerState<KnowledgeNotePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  late ReaderNoteFormat _noteFormat;

  /// 当前是否显示 Markdown 预览。
  bool _previewMode = false;

  /// 当前是否正在保存。
  bool _saving = false;

  /// 当前是否正在录音。
  bool _recording = false;

  /// record 插件实例。
  late final AudioRecorder _audioRecorder;

  /// 当前录音的临时文件路径。
  String? _recordingPath;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.note.title,
    );

    _contentController = TextEditingController(
      text: widget.note.content,
    );

    _noteFormat = widget.note.noteFormat;

    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _audioRecorder.dispose();

    super.dispose();
  }

  /// 保存当前 Note。
  ///
  /// 所有编辑内容最终还是进入 ReaderAnnotation。
  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final updatedNote = widget.note.copyWith(
        title: _titleController.text.trim(),
        content: _contentController.text,
        noteFormat: _noteFormat,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(
            readerAnnotationsProvider(widget.document).notifier,
          )
          .add(updatedNote);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedNote);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  /// 删除当前 Note。
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除笔记'),
          content: const Text(
            '确定删除这条笔记吗？此操作不可撤销。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(
          readerAnnotationsProvider(widget.document).notifier,
        )
        .remove(widget.note.id);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  /// 回到当前 Note 对应的 PDF 页面。
  void _openPdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          document: widget.document,
          initialPage: widget.note.pageIndex,
        ),
      ),
    );
  }

  /// 拍照并插入 Note。
  ///
  /// 流程：
  ///
  /// Camera
  ///   ↓
  /// 临时 jpg
  ///   ↓
  /// attachments/
  ///   ↓
  /// Markdown 图片引用
  ///   ↓
  /// ReaderAnnotation
  Future<void> _takePhoto() async {
    if (_previewMode || _saving) {
      return;
    }

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _showMessage('没有检测到可用摄像头');
        return;
      }

      final camera = cameras.first;

      if (!mounted) {
        return;
      }

      final result = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => _CameraCapturePage(
            camera: camera,
          ),
        ),
      );

      if (result == null) {
        return;
      }

      final reference =
          await const ReaderAnnotationService()
              .importAttachmentReference(
        widget.document,
        result.path,
      );

      _appendImageReference(reference);
    } catch (error) {
      _showMessage('拍照失败：$error');
    }
  }

  /// 录音。
  ///
  /// 第一次点击：
  ///
  /// 开始录音。
  ///
  /// 第二次点击：
  ///
  /// 停止录音并插入 Markdown 音频链接。
  Future<void> _toggleRecording() async {
    if (_previewMode || _saving) {
      return;
    }

    if (_recording) {
      await _stopRecording();
      return;
    }

    try {
      final hasPermission =
          await _audioRecorder.hasPermission();

      if (!hasPermission) {
        _showMessage('没有录音权限');
        return;
      }

      final temporaryDirectory =
          await getTemporaryDirectory();

      final timestamp =
          DateTime.now().microsecondsSinceEpoch;

      final path = '${temporaryDirectory.path}'
          '${Platform.pathSeparator}'
          'medicalreader_recording_$timestamp.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
        ),
        path: path,
      );

      if (!mounted) {
        return;
      }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _recording = false;
      });

      final sourcePath =
          temporaryPath ?? _recordingPath;

      _recordingPath = null;

      if (sourcePath == null) {
        _showMessage('录音文件不存在');
        return;
      }

      final reference =
          await const ReaderAnnotationService()
              .importAttachmentReference(
        widget.document,
        sourcePath,
      );

      _appendAudioReference(reference);

      // 临时录音文件已经复制到书籍目录，
      // 因此删除临时文件。
      try {
        await File(sourcePath).delete();
      } catch (_) {
        // 临时文件清理失败不影响 Note。
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recording = false;
        });
      }

      _showMessage('停止录音失败：$error');
    }
  }

  /// 在正文最后另起一行插入图片。
  void _appendImageReference(String reference) {
    final current = _contentController.text;

    final separator = current.isEmpty
        ? ''
        : current.endsWith('\n')
            ? '\n'
            : '\n\n';

    _contentController.text =
        '$current'
        '$separator'
        '![图片]($reference)';

    _contentController.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset: _contentController.text.length,
      ),
    );

    setState(() {});
  }

  /// 在正文最后另起一行插入录音。
  void _appendAudioReference(String reference) {
    final current = _contentController.text;

    final separator = current.isEmpty
        ? ''
        : current.endsWith('\n')
            ? '\n'
            : '\n\n';

    _contentController.text =
        '$current'
        '$separator'
        '[录音]($reference)';

    _contentController.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset: _contentController.text.length,
      ),
    );

    setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            tooltip: _previewMode ? '编辑' : '预览',
            icon: Icon(
              _previewMode
                  ? Icons.edit_outlined
                  : Icons.preview_outlined,
            ),
            onPressed: _recording
                ? null
                : () {
                    setState(() {
                      _previewMode = !_previewMode;
                    });
                  },
          ),
          IconButton(
            tooltip: '定位 PDF',
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
            ),
            onPressed: _recording ? null : _openPdf,
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: _recording ? null : _delete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.document.title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '第 ${widget.note.pageIndex + 1} 页',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(width: 12),
                DropdownButton<ReaderNoteFormat>(
                  value: _noteFormat,
                  onChanged:
                      _previewMode || _recording
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _noteFormat = value;
                              });
                            },
                  items: const [
                    DropdownMenuItem(
                      value: ReaderNoteFormat.markdown,
                      child: Text('Markdown'),
                    ),
                    DropdownMenuItem(
                      value: ReaderNoteFormat.markdownHtml,
                      child: Text('Markdown + HTML'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _previewMode
                ? Markdown(
                    data: _contentController.text,
                    padding: const EdgeInsets.all(20),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical:
                          TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText:
                            '在这里编写 Markdown 笔记...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
          ),

          if (!_previewMode)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  4,
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving || _recording
                          ? null
                          : _takePhoto,
                      icon: const Icon(
                        Icons.photo_camera_outlined,
                      ),
                      label: const Text('拍照'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : _toggleRecording,
                      icon: Icon(
                        _recording
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none_outlined,
                      ),
                      label: Text(
                        _recording
                            ? '停止录音'
                            : '录音',
                      ),
                    ),
                    if (_recording)
                      const Padding(
                        padding:
                            EdgeInsets.only(left: 12),
                        child: Text('正在录音...'),
                      ),
                  ],
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
                  onPressed:
                      _saving || _recording ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? '保存中...' : '保存笔记',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 独立的拍照页面。
///
/// 不把 CameraController 塞进 KnowledgeNotePage，
/// 避免 Note 编辑页面同时管理摄像头生命周期。
class _CameraCapturePage extends StatefulWidget {
  final CameraDescription camera;

  const _CameraCapturePage({
    required this.camera,
  });

  @override
  State<_CameraCapturePage> createState() =>
      _CameraCapturePageState();
}

class _CameraCapturePageState
    extends State<_CameraCapturePage> {
  late final CameraController _controller;

  late final Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
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
      await _initializeFuture;

      final image = await _controller.takePicture();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(image);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('拍照失败：$error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照'),
      ),
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                '摄像头初始化失败：${snapshot.error}',
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FloatingActionButton.large(
                    onPressed: _capture,
                    child: const Icon(
                      Icons.camera_alt,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}