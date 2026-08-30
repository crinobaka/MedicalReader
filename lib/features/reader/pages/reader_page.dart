import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../controllers/reader_page_controller.dart';
import '../models/reader_annotation.dart';
import '../services/book_tree_service.dart';
import '../services/reader_annotation_service.dart';
import '../services/reader_search_service.dart';
import '../widgets/book_tree_editor_dialog.dart';
import '../widgets/book_tree_panel.dart';
import '../widgets/reader_note_dialog.dart';
import '../widgets/reader_page_jump_dialogs.dart';
import '../widgets/reader_page_layout.dart';
import '../widgets/reader_serch_dialog.dart';
import '../widgets/reader_settings_panel.dart';
import '../providers/reader_annotation_provider.dart';
import '../providers/reader_view_options_provider.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.document, this.initialPage = 0});
  final LibraryDocument document; final int initialPage;
  @override ConsumerState<ReaderPage> createState()=>_ReaderPageState();
}
class _ReaderPageState extends ConsumerState<ReaderPage>{
  late final ReaderPageController _controller;
  final ReaderSearchService _searchService=const ReaderSearchService();
  final AudioRecorder _audioRecorder=AudioRecorder();
  late final FocusNode _focusNode; late final TransformationController _transformationController;
  List<ReaderSearchHit> _searchHits=const [];
  @override void initState(){super.initState();_focusNode=FocusNode();_transformationController=TransformationController();_controller=ReaderPageController(documentInfo:widget.document,initialPage:widget.initialPage,libraryRepository:ref.read(libraryRepositoryProvider))..open();}
  List<ReaderAnnotation> get _annotations=>ref.read(readerAnnotationsProvider(widget.document)).where((x)=>x.pageIndex==_controller.currentPage).toList(growable:false);
  bool get _bookmarked=>_annotations.any((x)=>x.type==ReaderAnnotationType.bookmark);
  Future<void> _toggleBookmark()async{if(_controller.pageLoading)return;final n=ref.read(readerAnnotationsProvider(widget.document).notifier);final e=_annotations.where((x)=>x.type==ReaderAnnotationType.bookmark);if(e.isNotEmpty){for(final x in e)await n.remove(x.id);return;}final now=DateTime.now();await n.add(ReaderAnnotation(id:'bookmark_${widget.document.id}_${_controller.currentPage}',bookId:widget.document.id,pageIndex:_controller.currentPage,type:ReaderAnnotationType.bookmark,createdAt:now,updatedAt:now));}
  Future<void> _showSearch()async{final r=await showDialog<ReaderSearchResult>(context:context,builder:(c)=>ReaderSearchDialog(searchService:_searchService,documentId:widget.document.file.id,documentPath:widget.document.file.path,currentPage:_controller.currentPage,bookTreeIndex:_controller.bookTreeIndex,bookPageMapping:_controller.bookPageMapping,bookTemplate:_controller.bookTemplate,searchContext:{...? _controller.bookTemplate?.searchContext,...? _controller.bookManifest?.searchContext}));if(r==null||!mounted)return;setState(()=>_searchHits=r.hits);await _controller.goToPage(r.pageIndex);_focusNode.requestFocus();}
  Future<void> _editBookTree()async{final result=await showDialog<List<dynamic>>(context:context,builder:(c)=>BookTreeEditorDialog(nodes:_controller.bookTreeIndex.nodes));if(result==null||!mounted)return;final nodes=result.whereType<dynamic>().where((x)=>x is dynamic).toList();await const BookTreeService().saveTreeForDocument(widget.document,nodes.cast());await _controller.retry();}
  Future<void> _showBookTree()async{await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(c)=>SizedBox(height:MediaQuery.sizeOf(c).height*.85,child:BookTreePanel(nodes:_controller.bookTreeIndex.nodes,currentPage:_controller.currentPage,currentNodeId:_controller.currentBookTreeNode?.id,onEdit:_editBookTree,onPageSelected:(p){Navigator.pop(c);unawaited(_controller.goToPage(p));}}));if(mounted)_focusNode.requestFocus();}
  Future<void> _showNote()async{if(_controller.pageLoading)return;final n=ref.read(readerAnnotationsProvider(widget.document).notifier);final e=_annotations.where((x)=>x.type==ReaderAnnotationType.note);final note=e.isNotEmpty?e.first:ReaderAnnotation(id:'note_${widget.document.id}_${_controller.currentPage}',bookId:widget.document.id,pageIndex:_controller.currentPage,type:ReaderAnnotationType.note,title:'PDF 第 ${_controller.currentPage+1} 页笔记',createdAt:DateTime.now(),updatedAt:DateTime.now());final r=await showDialog<ReaderAnnotation>(context:context,builder:(c)=>ReaderNoteDialog(note:note,onInsertImage:()async{final f=await FilePicker.pickFiles(type:FileType.image);if(f.isEmpty)return null;final p=f.first.path;if(p==null||p.isEmpty)return null;return const ReaderAnnotationService().importAttachment(widget.document,p);},onInsertAudio:_recordAudio));if(r!=null)await n.add(r);}
  Future<String?> _recordAudio()async{if(!await _audioRecorder.hasPermission())return null;final s=const ReaderAnnotationService();final d=await s.ensureAttachmentsDirectory(widget.document);final p='${d.path}${Platform.pathSeparator}audio_${DateTime.now().microsecondsSinceEpoch}.wav';await _audioRecorder.start(const RecordConfig(encoder:AudioEncoder.wav),path:p);if(!mounted)return null;final stop=await showDialog<bool>(context:context,barrierDismissible:false,builder:(c)=>AlertDialog(title:const Text('正在录音'),content:const Text('录音完成后点击“停止”。'),actions:[FilledButton.icon(onPressed:()=>Navigator.pop(c,true),icon:const Icon(Icons.stop),label:const Text('停止'))]))??false;if(!stop){await _audioRecorder.stop();return null;}return _audioRecorder.stop();}
  Future<void> _showSettings()async{await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(c)=>DraggableScrollableSheet(expand:false,initialChildSize:.82,minChildSize:.45,maxChildSize:.96,builder:(c,sc)=>Consumer(builder:(c,ref,_){final o=ref.watch(readerViewOptionsProvider);return SafeArea(child:ReaderSettingsPanel(options:o,onChanged:(v)=>ref.read(readerViewOptionsProvider.notifier).update(v),onReset:()=>ref.read(readerViewOptionsProvider.notifier).reset(),scrollController:sc));})));}
  Future<void> _showPageJump()async{final v=await showDialog<int>(context:context,builder:(c)=>PageJumpDialog(currentPage:_controller.currentPage+1,pageCount:_controller.pageCount));if(v!=null)await _controller.goToPage(v-1);}
  Future<void> _showBookPageJump()async{final v=await showDialog<int>(context:context,builder:(c)=>BookPageJumpDialog(currentPage:_controller.currentBookPage));if(v==null)return;final p=_controller.bookPageMapping.pdfPageForBookPage(v);if(p!=null)await _controller.goToPage(p);}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:_controller,builder:(c,_){final path=_controller.currentBookTreePath;return ReaderPageLayout(locationLabel:_controller.currentLocationLabel,searchLocationLabel:path.isEmpty?null:'命中 · ${path.map((n)=>n.name).join(' / ')}',loading:_controller.loading,pageLoading:_controller.pageLoading,error:_controller.error,image:_controller.image,previousPageImage:_controller.previousPageImage,nextPageImage:_controller.nextPageImage,searchHits:_searchHits,bookmarked:_bookmarked,cropEnabled:_controller.cropMargins,canGoPrevious:_controller.currentPage>0,canGoNext:_controller.currentPage<_controller.pageCount-1,currentPage:_controller.currentPage,pageCount:_controller.pageCount,bookPage:_controller.currentBookPage,currentBookTreeNode:_controller.currentBookTreeNode,searchResultPath:path,keyboardFocusNode:_focusNode,transformationController:_transformationController,onPrevious:_controller.previousPage,onNext:_controller.nextPage,onFirst:_controller.firstPage,onLast:_controller.lastPage,onPageJump:_showPageJump,onBookPageJump:_showBookPageJump,onBookTree:_showBookTree,onSearch:_showSearch,onBookmark:_toggleBookmark,onNote:_showNote,onCropChanged:_controller.setCropMargins,onSettings:_showSettings,onRetry:()=>unawaited(_controller.retry()));});
  @override void dispose(){_focusNode.dispose();_transformationController.dispose();_audioRecorder.dispose();_controller.dispose();super.dispose();}
}
