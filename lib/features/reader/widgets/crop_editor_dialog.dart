import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/crop_configuration.dart';
import '../services/crop_engine_service.dart';
import 'crop_editor_toolbar.dart';
import 'crop_region_canvas.dart';

class CropEditorDialog extends StatefulWidget {
  final CropConfiguration initial;
  final ui.Image? previewImage;
  const CropEditorDialog({super.key, required this.initial, this.previewImage});
  @override State<CropEditorDialog> createState() => _CropEditorDialogState();
}
class _CropEditorDialogState extends State<CropEditorDialog> {
  final CropEngineService _engine = const CropEngineService();
  late CropTemplate _template; late CropLayout _layout; late CropPageBasis _pageBasis; late bool _inheritPrevious;
  late double _left,_right,_top,_bottom; late int? _pageStart,_pageEnd; late List<CropPageRange> _pageRanges; late List<CropRegion> _regions;
  CropEditorTool _tool=CropEditorTool.select;
  final _start=TextEditingController(),_end=TextEditingController(),_ranges=TextEditingController();
  @override void initState(){super.initState();final v=widget.initial;_template=v.template;_layout=v.layout;_pageBasis=v.pageBasis;_inheritPrevious=v.inheritPrevious;_left=v.adjustment.left;_right=v.adjustment.right;_top=v.adjustment.top;_bottom=v.adjustment.bottom;_pageStart=v.pageStart;_pageEnd=v.pageEnd;_pageRanges=List.of(v.pageRanges);_regions=List.of(v.regions);_start.text=v.pageStart?.toString()??'';_end.text=v.pageEnd?.toString()??'';_ranges.text=v.pageRanges.map((r)=>r.label).join(', ');}
  @override void dispose(){_start.dispose();_end.dispose();_ranges.dispose();super.dispose();}
  void _materialize(){if(_regions.isEmpty)_regions=List.of(_engine.defaultRegions(_template));}
  void _templateChanged(CropTemplate v){setState((){_template=v;_regions=List.of(_engine.defaultRegions(v));});}
  void _toggle(int i){setState((){_materialize();_template=CropTemplate.custom;_regions[i]=_regions[i].copyWith(excluded:!_regions[i].excluded);});}
  void _add(CropRegion r){setState((){_regions=[..._regions,r.clamp()];_template=CropTemplate.custom;});}
  void _change(int i,CropRegion r){setState((){_materialize();_template=CropTemplate.custom;_regions[i]=r.clamp();});}
  List<CropRegion> get _preview=> (_regions.isNotEmpty?_regions:_engine.defaultRegions(_template)).map((r)=>r.adjust(CropAdjustment(left:_left,right:_right,top:_top,bottom:_bottom))).where((r)=>r.width>0&&r.height>0).toList();
  List<CropPageRange> _parse(String text){final o=<CropPageRange>[];for(final t in text.split(',')){final p=t.trim().split(RegExp(r'[-~:]'));final a=int.tryParse(p.first);final b=p.length>1?int.tryParse(p[1]):a;if(a!=null&&b!=null&&a>0&&b>0)o.add(CropPageRange(start:a<b?a:b,end:a<b?b:a));}o.sort((a,b)=>a.start.compareTo(b.start));return o;}
  void _submit(){_pageStart=int.tryParse(_start.text.trim());_pageEnd=int.tryParse(_end.text.trim());_pageRanges=_parse(_ranges.text);Navigator.of(context).pop(CropConfiguration(template:_template,layout:_layout,regions:_regions.map((r)=>r.clamp()).toList(),pageStart:_pageStart,pageEnd:_pageEnd,pageBasis:_pageBasis,pageRanges:_pageRanges,inheritPrevious:_inheritPrevious,adjustment:CropAdjustment(left:_left,right:_right,top:_top,bottom:_bottom),sourceDocumentId:widget.initial.sourceDocumentId,temporarySessionId:widget.initial.temporarySessionId,createdAt:widget.initial.createdAt));}
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('可视化裁剪'),content:SizedBox(width:900,height:620,child:Column(children:[Expanded(child:Stack(children:[Positioned.fill(child:CropRegionCanvas(image:widget.previewImage,regions:_preview,tool:_tool,onLongPressRegion:_toggle,onChanged:_change,onCreateRegion:_add)),Positioned(left:12,bottom:12,child:CropEditorToolbar(selected:_tool,onSelected:(v)=>setState(()=>_tool=v),onClear:()=>setState(()=>_regions=[])))])),const SizedBox(height:8),Text('矩形拖拽创建；分隔线可切开已有区域；多边形点击顶点后回点首点完成。长按区域可排除/恢复，排除区域不编号、不输出。',style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:8),Row(children:[Expanded(child:DropdownButtonFormField<CropTemplate>(initialValue:_template,decoration:const InputDecoration(labelText:'模板'),items:const [DropdownMenuItem(value:CropTemplate.single,child:Text('单栏')),DropdownMenuItem(value:CropTemplate.doubleColumn,child:Text('双栏')),DropdownMenuItem(value:CropTemplate.tripleColumn,child:Text('三栏')),DropdownMenuItem(value:CropTemplate.custom,child:Text('自定义')),DropdownMenuItem(value:CropTemplate.bookTemplate,child:Text('书籍模板'))],onChanged:(v){if(v!=null)_templateChanged(v);})) ,const SizedBox(width:12),Expanded(child:DropdownButtonFormField<CropLayout>(initialValue:_layout,decoration:const InputDecoration(labelText:'输出布局'),items:const [DropdownMenuItem(value:CropLayout.horizontal,child:Text('横向拼接')),DropdownMenuItem(value:CropLayout.grid,child:Text('自动网格'))],onChanged:(v){if(v!=null)setState(()=>_layout=v);})),const SizedBox(width:12),Expanded(child:DropdownButtonFormField<CropPageBasis>(initialValue:_pageBasis,decoration:const InputDecoration(labelText:'页码依据'),items:const [DropdownMenuItem(value:CropPageBasis.pdf,child:Text('PDF 页')),DropdownMenuItem(value:CropPageBasis.book,child:Text('书籍页'))],onChanged:(v){if(v!=null)setState(()=>_pageBasis=v);}))]),const SizedBox(height:6),Row(children:[Expanded(child:TextField(controller:_ranges,decoration:const InputDecoration(labelText:'组合页',hintText:'12-15, 30-55, 80'))),const SizedBox(width:12),Expanded(child:TextField(controller:_start,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'起始页'))),const SizedBox(width:12),Expanded(child:TextField(controller:_end,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'结束页')))]),SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,title:const Text('继承上一页裁剪'),value:_inheritPrevious,onChanged:(v)=>setState(()=>_inheritPrevious=v))])),actions:[TextButton(onPressed:()=>Navigator.of(context).pop(),child:const Text('取消')),FilledButton(onPressed:_submit,child:const Text('保存并应用'))]);
}
