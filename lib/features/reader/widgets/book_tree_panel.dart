import 'package:flutter/material.dart';
import '../models/book_tree_node.dart';

class BookTreePanel extends StatefulWidget {
  final List<BookTreeNode> nodes;
  final int currentPage;
  final String? currentNodeId;
  final ValueChanged<int> onPageSelected;
  final VoidCallback? onEdit;
  const BookTreePanel({super.key, required this.nodes, required this.currentPage, this.currentNodeId, required this.onPageSelected, this.onEdit});
  @override State<BookTreePanel> createState() => _BookTreePanelState();
}
class _BookTreePanelState extends State<BookTreePanel> {
  final Set<String> _expandedNodes = <String>{};
  @override void initState(){super.initState();_syncExpandedNodes();}
  @override void didUpdateWidget(covariant BookTreePanel oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.currentPage!=widget.currentPage||oldWidget.nodes!=widget.nodes)_syncExpandedNodes();}
  void _syncExpandedNodes(){final path=<String>[];for(final node in widget.nodes){if(_collectCurrentPath(node,widget.currentPage,path))break;}if(path.isNotEmpty)setState(()=>_expandedNodes.addAll(path));}
  bool _collectCurrentPath(BookTreeNode node,int page,List<String> path){if(!node.containsPage(page))return false;path.add(node.id);for(final child in node.children){final p=<String>[];if(_collectCurrentPath(child,page,p)){path.addAll(p);return true;}}return true;}
  void _toggleNode(BookTreeNode node,bool expanded)=>setState(()=>expanded?_expandedNodes.add(node.id):_expandedNodes.remove(node.id));
  @override Widget build(BuildContext context)=>Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,12,8,8),child:Row(children:[const Expanded(child:Text('目录',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),if(widget.onEdit!=null)IconButton(tooltip:'编辑目录',onPressed:widget.onEdit,icon:const Icon(Icons.edit_note_rounded))])),const Divider(height:1),Expanded(child:widget.nodes.isEmpty?const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('暂无目录\n\n当前书籍没有加载目录索引。',textAlign:TextAlign.center))):ListView(padding:const EdgeInsets.symmetric(vertical:8),children:widget.nodes.map((n)=>_BookTreeNodeTile(node:n,level:0,currentPage:widget.currentPage,currentNodeId:widget.currentNodeId,expandedNodes:_expandedNodes,onExpansionChanged:_toggleNode,onPageSelected:widget.onPageSelected)).toList()))]);
}
class _BookTreeNodeTile extends StatelessWidget{
 final BookTreeNode node;final int level;final int currentPage;final String? currentNodeId;final Set<String> expandedNodes;final void Function(BookTreeNode,bool) onExpansionChanged;final ValueChanged<int> onPageSelected;
 const _BookTreeNodeTile({required this.node,required this.level,required this.currentPage,this.currentNodeId,required this.expandedNodes,required this.onExpansionChanged,required this.onPageSelected});
 String? _pageText(){final bs=node.bookPageStart,be=node.bookPageEnd,ps=node.pageStart,pe=node.pageEnd;if(bs!=null){final b=be==null?'书籍 P$bs':'书籍 P$bs-$be';if(ps==null)return b;return '$b · ${pe==null?'PDF P$ps':'PDF P$ps-$pe}';}if(ps==null)return null;return pe==null?'PDF P$ps':'PDF P$ps-$pe';}
 @override Widget build(BuildContext context){final has=node.children.isNotEmpty,current=currentNodeId!=null?node.id==currentNodeId:node.containsPage(currentPage),title=node.name.isEmpty?node.id:node.name,page=_pageText();if(!has)return ListTile(dense:level>1,selected:current,contentPadding:EdgeInsets.only(left:16+level*16,right:12),title:Text(title,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:page==null?null:Text(page),onTap:(){final p=node.resolvePdfPageIndex();if(p!=null)onPageSelected(p);});return ExpansionTile(key:PageStorageKey(node.id),initiallyExpanded:expandedNodes.contains(node.id),tilePadding:EdgeInsets.only(left:8+level*16,right:12),title:Text(title,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:page==null?null:Text(page),onExpansionChanged:(v)=>onExpansionChanged(node,v),children:node.children.map((c)=>_BookTreeNodeTile(node:c,level:level+1,currentPage:currentPage,currentNodeId:currentNodeId,expandedNodes:expandedNodes,onExpansionChanged:onExpansionChanged,onPageSelected:onPageSelected)).toList());}
}
