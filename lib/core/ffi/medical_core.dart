import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class _MedicalCoreDocument extends Opaque {}

final class _MedicalCorePage extends Struct {
  @Uint32() external int width;
  @Uint32() external int height;
  @Uint32() external int stride;
  @Uint8() external int components;
  external Pointer<Uint8> data;
  @IntPtr() external int dataLen;
}

typedef _MedicalCoreHelloNative = Int32 Function();
typedef _MedicalCoreHelloDart = int Function();
typedef _MedicalCoreOpenBookNative = Pointer<_MedicalCoreDocument> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _MedicalCoreOpenBookDart = Pointer<_MedicalCoreDocument> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _MedicalCoreCloseBookNative = Void Function(Pointer<_MedicalCoreDocument>);
typedef _MedicalCoreCloseBookDart = void Function(Pointer<_MedicalCoreDocument>);
typedef _MedicalCoreGetPageCountNative = Int32 Function(Pointer<_MedicalCoreDocument>, Pointer<Uint32>);
typedef _MedicalCoreGetPageCountDart = int Function(Pointer<_MedicalCoreDocument>, Pointer<Uint32>);
typedef _MedicalCoreRenderPageNative = Pointer<_MedicalCorePage> Function(Pointer<_MedicalCoreDocument>, Uint32, Uint32);
typedef _MedicalCoreRenderPageDart = Pointer<_MedicalCorePage> Function(Pointer<_MedicalCoreDocument>, int, int);
typedef _MedicalCoreFreePageNative = Void Function(Pointer<_MedicalCorePage>);
typedef _MedicalCoreFreePageDart = void Function(Pointer<_MedicalCorePage>);
typedef _MedicalCoreGetOutlineNative = Pointer<Utf8> Function(Pointer<_MedicalCoreDocument>);
typedef _MedicalCoreGetOutlineDart = Pointer<Utf8> Function(Pointer<_MedicalCoreDocument>);
typedef _MedicalCoreSearchBookNative = Pointer<Utf8> Function(Pointer<_MedicalCoreDocument>, Pointer<Utf8>, Uint32, Uint32, Uint32);
typedef _MedicalCoreSearchBookDart = Pointer<Utf8> Function(Pointer<_MedicalCoreDocument>, Pointer<Utf8>, int, int, int);
typedef _MedicalCoreFreeStringNative = Void Function(Pointer<Utf8>);
typedef _MedicalCoreFreeStringDart = void Function(Pointer<Utf8>);

class MedicalCorePage {
  final int width;
  final int height;
  final int stride;
  final int components;
  final List<int> data;
  const MedicalCorePage({required this.width, required this.height, required this.stride, required this.components, required this.data});
}

class MedicalCoreDocument {
  final Pointer<_MedicalCoreDocument> _handle;
  final MedicalCore _core;
  bool _closed = false;
  MedicalCoreDocument._({required Pointer<_MedicalCoreDocument> handle, required MedicalCore core}) : _handle = handle, _core = core;
  int get pageCount { if (_closed) throw StateError('MedicalCoreDocument is already closed.'); return _core.getPageCount(_handle); }
  MedicalCorePage renderPage({required int pageIndex, required int dpi}) { if (_closed) throw StateError('MedicalCoreDocument is already closed.'); return _core.renderPage(_handle, pageIndex: pageIndex, dpi: dpi); }
  String getOutlineJson() { if (_closed) throw StateError('MedicalCoreDocument is already closed.'); return _core.getOutline(_handle); }
  String searchBook({required String query, int maxResults = 50, int contextBefore = 80, int contextAfter = 80}) { if (_closed) throw StateError('MedicalCoreDocument is already closed.'); return _core.searchBook(_handle, query: query, maxResults: maxResults, contextBefore: contextBefore, contextAfter: contextAfter); }
  void close() { if (_closed) return; _core.closeBook(_handle); _closed = true; }
}

class MedicalCore {
  MedicalCore._(this._library) {
    _hello = _library.lookupFunction<_MedicalCoreHelloNative, _MedicalCoreHelloDart>('medical_core_hello');
    _openBook = _library.lookupFunction<_MedicalCoreOpenBookNative, _MedicalCoreOpenBookDart>('medical_core_open_book');
    _closeBook = _library.lookupFunction<_MedicalCoreCloseBookNative, _MedicalCoreCloseBookDart>('medical_core_close_book');
    _getPageCount = _library.lookupFunction<_MedicalCoreGetPageCountNative, _MedicalCoreGetPageCountDart>('medical_core_get_page_count');
    _renderPage = _library.lookupFunction<_MedicalCoreRenderPageNative, _MedicalCoreRenderPageDart>('medical_core_render_page');
    _freePage = _library.lookupFunction<_MedicalCoreFreePageNative, _MedicalCoreFreePageDart>('medical_core_free_page');
    _getOutline = _library.lookupFunction<_MedicalCoreGetOutlineNative, _MedicalCoreGetOutlineDart>('medical_core_get_outline');
    _searchBook = _library.lookupFunction<_MedicalCoreSearchBookNative, _MedicalCoreSearchBookDart>('medical_core_search_book');
    _freeString = _library.lookupFunction<_MedicalCoreFreeStringNative, _MedicalCoreFreeStringDart>('medical_core_free_string');
  }

  static MedicalCore? _instance;
  final DynamicLibrary _library;
  late final _MedicalCoreHelloDart _hello;
  late final _MedicalCoreOpenBookDart _openBook;
  late final _MedicalCoreCloseBookDart _closeBook;
  late final _MedicalCoreGetPageCountDart _getPageCount;
  late final _MedicalCoreRenderPageDart _renderPage;
  late final _MedicalCoreFreePageDart _freePage;
  late final _MedicalCoreGetOutlineDart _getOutline;
  late final _MedicalCoreSearchBookDart _searchBook;
  late final _MedicalCoreFreeStringDart _freeString;

  factory MedicalCore() => _instance ??= MedicalCore._(_openLibrary());
  int hello() => _hello();

  MedicalCoreDocument openBook({required String id, required String path}) {
    final idPointer = id.toNativeUtf8();
    final pathPointer = path.toNativeUtf8();
    try {
      final handle = _openBook(idPointer, pathPointer);
      if (handle == nullptr) throw StateError('Failed to open document: $path');
      return MedicalCoreDocument._(handle: handle, core: this);
    } finally { calloc.free(idPointer); calloc.free(pathPointer); }
  }

  void closeBook(Pointer<_MedicalCoreDocument> handle) { if (handle != nullptr) _closeBook(handle); }
  int getPageCount(Pointer<_MedicalCoreDocument> handle) {
    if (handle == nullptr) throw ArgumentError('Document handle cannot be null.');
    final pointer = calloc<Uint32>();
    try { final result = _getPageCount(handle, pointer); if (result != 0) throw StateError('Failed to get PDF page count.'); return pointer.value; }
    finally { calloc.free(pointer); }
  }

  MedicalCorePage renderPage(Pointer<_MedicalCoreDocument> handle, {required int pageIndex, required int dpi}) {
    if (handle == nullptr) throw ArgumentError('Document handle cannot be null.');
    if (pageIndex < 0) throw ArgumentError.value(pageIndex, 'pageIndex', 'Page index cannot be negative.');
    if (dpi <= 0) throw ArgumentError.value(dpi, 'dpi', 'DPI must be greater than zero.');
    final pointer = _renderPage(handle, pageIndex, dpi);
    if (pointer == nullptr) throw StateError('Failed to render PDF page: $pageIndex');
    try {
      final page = pointer.ref;
      return MedicalCorePage(width: page.width, height: page.height, stride: page.stride, components: page.components, data: List<int>.from(page.data.asTypedList(page.dataLen)));
    } finally { _freePage(pointer); }
  }

  String getOutline(Pointer<_MedicalCoreDocument> handle) {
    if (handle == nullptr) throw ArgumentError('Document handle cannot be null.');
    final pointer = _getOutline(handle);
    if (pointer == nullptr) throw StateError('Failed to read PDF outline.');
    try { return pointer.toDartString(); } finally { _freeString(pointer); }
  }

  String searchBook(Pointer<_MedicalCoreDocument> handle, {required String query, required int maxResults, int contextBefore = 80, int contextAfter = 80}) {
    if (handle == nullptr) throw ArgumentError('Document handle cannot be null.');
    final normalized = query.trim();
    if (normalized.isEmpty) return '';
    if (maxResults <= 0) throw ArgumentError.value(maxResults, 'maxResults', 'Maximum results must be greater than zero.');
    final queryPointer = normalized.toNativeUtf8();
    try {
      final pointer = _searchBook(handle, queryPointer, maxResults, contextBefore, contextAfter);
      if (pointer == nullptr) throw StateError('Failed to search PDF document.');
      try { return pointer.toDartString(); } finally { _freeString(pointer); }
    } finally { calloc.free(queryPointer); }
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) return DynamicLibrary.open('libmedical_core.so');
    if (Platform.isWindows) return DynamicLibrary.open('medical_core.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libmedical_core.dylib');
    if (Platform.isLinux) return DynamicLibrary.open('libmedical_core.so');
    throw UnsupportedError('MedicalCore is not supported on this platform.');
  }
}
