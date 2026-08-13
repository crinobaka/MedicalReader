import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/ffi/medical_core.dart';
import '../../library/models/library_document.dart';
import '../services/reader_engine_service.dart';

class ReaderPage extends StatefulWidget {
  final LibraryDocument document;

  const ReaderPage({super.key, required this.document});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final ReaderEngineService _readerEngine = ReaderEngineService();

  MedicalCoreDocument? _document;

  ui.Image? _image;

  bool _loading = true;

  Object? _error;

  @override
  void initState() {
    super.initState();

    _openDocument();
  }

  Future<void> _openDocument() async {
    MedicalCoreDocument? document;
    ui.Image? image;

    try {
      document = _readerEngine.openDocument(
        id: widget.document.file.id,
        path: widget.document.file.path,
      );

      final pageCount = document.pageCount;

      if (pageCount <= 0) {
        document.close();
        document = null;

        throw StateError('PDF contains no pages.');
      }

      image = await _readerEngine.renderPage(
        document: document,
        pageIndex: 0,
        dpi: 150,
      );

      if (!mounted) {
        image.dispose();
        document.close();
        return;
      }

      setState(() {
        _document = document;
        _image = image;
        _loading = false;
        _error = null;
      });

      document = null;
      image = null;
    } catch (error) {
      image?.dispose();
      document?.close();

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _document?.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to open PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });

                  _openDocument();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final image = _image;

    if (image == null) {
      return const Center(child: Text('No page available.'));
    }

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: RawImage(image: image, fit: BoxFit.contain),
      ),
    );
  }
}
