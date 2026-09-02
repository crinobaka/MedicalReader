import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum ReaderInkTool { pen, highlighter, eraser }

class ReaderInkLayer extends StatefulWidget {
  final List<List<Offset>> strokes;
  final ValueChanged<List<Offset>> onStrokeEnd;
  final bool enabled;
  final Color color;
  final double width;
  const ReaderInkLayer({super.key,required this.strokes,required this.onStrokeEnd,required this.enabled,this.color=Colors.red,this.width=2.6});
  @override State<ReaderInkLayer> createState()=>_ReaderInkLayerState();
}
class _ReaderInkLayerState extends State<ReaderInkLayer>{
  List<Offset> _current=const[]; ReaderInkTool _tool=ReaderInkTool.pen; final List<List<Offset>> _localErased=[]; Size _size=Size.zero;
  void _start(DragStartDetails d){if(widget.enabled)setState(()=>_current=[d.localPosition]);}
  void _update(DragUpdateDetails d){if(widget.enabled&&_current.isNotEmpty)setState(()=>_current=[..._current,d.localPosition]);}
  void _end(DragEndDetails d){if(!widget.enabled||_current.length<2){if(mounted)setState(()=>_current=const[]);return;}final stroke=_current;setState(()=>_current=const[]);if(_tool==ReaderInkTool.eraser){final hit=_hit(stroke);if(hit!=null){setState(()=>_localErased.add(hit));widget.onStrokeEnd([const Offset(0,0),const Offset(0,1),..._strip(hit)]);}return;}widget.onStrokeEnd(_encode(stroke));}
  List<Offset> _encode(List<Offset> p){final opacity=_tool==ReaderInkTool.highlighter?.28:1.0;final m=<Offset>[const Offset(.999999,.999999),Offset(_tool.index/10,.5),Offset(widget.color.value/0xffffffff,.5),Offset(widget.width/100,.5),Offset(opacity,.5)];return [...m.map((x)=>Offset(x.dx*_size.width,x.dy*_size.height)),...p];}
  List<Offset> _strip(List<Offset> p)=>p.length>=5&&p.first.dx>_size.width*.99&&p.first.dy>_size.height*.99?p.sublist(5):p;
  List<Offset>? _hit(List<Offset> e){const t=18.0;for(final s in widget.strokes.reversed){final p=_strip(s);for(var i=1;i<p.length;i++){for(var j=1;j<e.length;j++){if(_dist(e[j-1],p[i-1],p[i])<=t||_dist(e[j],p[i-1],p[i])<=t||_dist(p[i-1],e[j-1],e[j])<=t)return s;}}}return null;}
  double _dist(Offset p,Offset a,Offset b){final dx=b.dx-a.dx,dy=b.dy-a.dy,l=dx*dx+dy*dy;if(l==0)return(p-a).distance;final q=((((p.dx-a.dx)*dx)+((p.dy-a.dy)*dy))/l).clamp(0.0,1.0).toDouble();return(p-Offset(a.dx+q*dx,a.dy+q*dy)).distance;}
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,c){_size=Size(c.maxWidth,c.maxHeight);final visible=widget.strokes.where((s)=>!_localErased.any((e)=>_same(e,s))).toList();final drawn=[...visible];if(_current.length>=2&&_tool!=ReaderInkTool.eraser)drawn.add(_encode(_current));final scheme=Theme.of(context).colorScheme;return Stack(fit:StackFit.expand,children:[GestureDetector(behavior:widget.enabled?HitTestBehavior.opaque:HitTestBehavior.translucent,onPanStart:_start,onPanUpdate:_update,onPanEnd:_end,child:CustomPaint(painter:_Painter(drawn),size:Size.infinite)),if(widget.enabled)Positioned(left:12,bottom:12,child:Material(elevation:4,borderRadius:BorderRadius.circular(18),color:scheme.surface.withValues(alpha:.96),child:Row(mainAxisSize:MainAxisSize.min,children:[_button(Icons.edit,'笔',ReaderInkTool.pen),_button(Icons.highlight,'荧光笔',ReaderInkTool.highlighter),_button(Icons.auto_fix_off,'橡皮擦',ReaderInkTool.eraser)])))]);});
  Widget _button(IconData i,String t,ReaderInkTool tool)=>IconButton(tooltip:t,onPressed:()=>setState(()=>_tool=tool),style:IconButton.styleFrom(backgroundColor:_tool==tool?Theme.of(context).colorScheme.primaryContainer:null),icon:Icon(i));
  bool _same(List<Offset>a,List<Offset>b){final x=_strip(a),y=_strip(b);if(x.length!=y.length)return false;for(var i=0;i<x.length;i++)if((x[i]-y[i]).distance>.5)return false;return true;}
}
class _Painter extends CustomPainter{final List<List<Offset>> strokes;const _Painter(this.strokes);@override void paint(Canvas c,Size s){for(final e in strokes){if(e.length<2)continue;var tool=ReaderInkTool.pen;var color=Colors.red;var w=2.6;var opacity=1.0;var start=0;if(e.length>=5&&e.first.dx>s.width*.99&&e.first.dy>s.height*.99){tool=ReaderInkTool.values[(e[1].dx/s.width*10).round().clamp(0,2).toInt()];color=Color(((e[2].dx/s.width).clamp(0.0,1.0)*0xffffffff).round());w=(e[3].dx/s.width).clamp(.001,1.0)*100;opacity=(e[4].dx/s.width).clamp(.05,1.0);start=5;}final p=e.sublist(start);if(p.length<2)continue;final paint=Paint()..color=color.withValues(alpha:opacity)..strokeWidth=tool==ReaderInkTool.highlighter?w*3.5:w..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round..style=PaintingStyle.stroke;if(tool==ReaderInkTool.highlighter)paint.blendMode=BlendMode.multiply;final path=ui.Path()..moveTo(p.first.dx,p.first.dy);for(var i=1;i<p.length;i++){final q=p[i],r=p[i-1],m=Offset((r.dx+q.dx)/2,(r.dy+q.dy)/2);path.quadraticBezierTo(r.dx,r.dy,m.dx,m.dy);}path.lineTo(p.last.dx,p.last.dy);c.drawPath(path,paint);}}@override bool shouldRepaint(covariant _Painter old)=>old.strokes!=strokes;}
