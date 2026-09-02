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
  List<Offset> _current=const[];
  ReaderInkTool _tool=ReaderInkTool.pen;
  final List<List<Offset>> _localErased=[];
  Size _size=Size.zero;

  void _start(DragStartDetails d){
    if(widget.enabled)setState(()=>_current=[d.localPosition]);
  }

  void _update(DragUpdateDetails d){
    if(widget.enabled&&_current.isNotEmpty)setState(()=>_current=[..._current,d.localPosition]);
  }

  void _end(DragEndDetails d){
    if(!widget.enabled||_current.length<2){
      if(mounted)setState(()=>_current=const[]);
      return;
    }
    final stroke=_current;
    setState(()=>_current=const[]);
    if(_tool==ReaderInkTool.eraser){
      final hit=_hit(stroke);
      if(hit!=null){
        setState(()=>_localErased.add(hit));
        widget.onStrokeEnd([const Offset(0,0),const Offset(0,1),..._strip(hit)]);
      }
      return;
    }
    widget.onStrokeEnd(_encode(stroke));
  }

  List<Offset> _encode(List<Offset> p){
    final opacity=_tool==ReaderInkTool.highlighter?.28:1.0;
    // Metadata is stored outside the visible path. The parent normalizes these
    // coordinates before persistence, so the painter can reconstruct tool
    // state without changing old annotation records.
    final m=<Offset>[
      const Offset(.999999,.999999),
      Offset(_tool.index/10,.5),
      Offset(widget.color.value/0xffffffff,.5),
      Offset(widget.width/100,.5),
      Offset(opacity,.5),
    ];
    return [...m.map((x)=>Offset(x.dx*_size.width,x.dy*_size.height)),...p];
  }

  List<Offset> _strip(List<Offset> p)=>
      p.length>=5&&p.first.dx>_size.width*.99&&p.first.dy>_size.height*.99?p.sublist(5):p;

  List<Offset>? _hit(List<Offset> eraser){
    const threshold=22.0;
    for(final stored in widget.strokes.reversed){
      final target=_strip(stored);
      if(target.length<2)continue;
      for(var i=1;i<target.length;i++){
        final a=target[i-1],b=target[i];
        for(var j=1;j<eraser.length;j++){
          final e0=eraser[j-1],e1=eraser[j];
          if(_segmentsNear(a,b,e0,e1,threshold))return stored;
        }
      }
    }
    return null;
  }

  bool _segmentsNear(Offset a,Offset b,Offset c,Offset d,double threshold){
    return _dist(a,c,d)<=threshold||_dist(b,c,d)<=threshold||
        _dist(c,a,b)<=threshold||_dist(d,a,b)<=threshold;
  }

  double _dist(Offset p,Offset a,Offset b){
    final dx=b.dx-a.dx,dy=b.dy-a.dy,l=dx*dx+dy*dy;
    if(l==0)return(p-a).distance;
    final q=((((p.dx-a.dx)*dx)+((p.dy-a.dy)*dy))/l).clamp(0.0,1.0).toDouble();
    return(p-Offset(a.dx+q*dx,a.dy+q*dy)).distance;
  }

  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder:(context,c){
    _size=Size(c.maxWidth,c.maxHeight);
    final visible=widget.strokes.where((s)=>!_localErased.any((e)=>_same(e,s))).toList();
    final scheme=Theme.of(context).colorScheme;
    return Stack(
      fit:StackFit.expand,
      children:[
        CustomPaint(
          painter:_Painter(strokes:visible,current:_current,tool:_tool,color:widget.color,width:widget.width,size:_size),
          size:Size.infinite,
        ),
        GestureDetector(
          behavior:widget.enabled?HitTestBehavior.opaque:HitTestBehavior.translucent,
          onPanStart:_start,
          onPanUpdate:_update,
          onPanEnd:_end,
          child:const SizedBox.expand(),
        ),
        if(widget.enabled)
          Positioned(
            left:12,bottom:12,
            child:Material(
              elevation:4,
              borderRadius:BorderRadius.circular(18),
              color:scheme.surface.withValues(alpha:.96),
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                _button(Icons.edit,'笔',ReaderInkTool.pen),
                _button(Icons.highlight,'荧光笔',ReaderInkTool.highlighter),
                _button(Icons.auto_fix_off,'橡皮擦',ReaderInkTool.eraser),
              ]),
            ),
          ),
      ],
    );
  });

  Widget _button(IconData i,String t,ReaderInkTool tool)=>IconButton(
    tooltip:t,
    onPressed:()=>setState(()=>_tool=tool),
    style:IconButton.styleFrom(backgroundColor:_tool==tool?Theme.of(context).colorScheme.primaryContainer:null),
    icon:Icon(i),
  );

  bool _same(List<Offset>a,List<Offset>b){
    final x=_strip(a),y=_strip(b);
    if(x.length!=y.length)return false;
    for(var i=0;i<x.length;i++)if((x[i]-y[i]).distance>.5)return false;
    return true;
  }
}

class _Painter extends CustomPainter{
  final List<List<Offset>> strokes;
  final List<Offset> current;
  final ReaderInkTool tool;
  final Color color;
  final double width;
  final Size size;
  const _Painter({required this.strokes,required this.current,required this.tool,required this.color,required this.width,required this.size});

  void _drawPath(Canvas c,List<Offset> p,Paint paint){
    if(p.length<2)return;
    final path=ui.Path()..moveTo(p.first.dx,p.first.dy);
    for(var i=1;i<p.length;i++){
      final q=p[i],r=p[i-1],m=Offset((r.dx+q.dx)/2,(r.dy+q.dy)/2);
      path.quadraticBezierTo(r.dx,r.dy,m.dx,m.dy);
    }
    path.lineTo(p.last.dx,p.last.dy);
    c.drawPath(path,paint);
  }

  Paint _paint(ReaderInkTool t,Color c,double w,double opacity){
    final p=Paint()
      ..color=c.withValues(alpha:opacity)
      ..strokeWidth=t==ReaderInkTool.highlighter?w*3.5:w
      ..strokeCap=StrokeCap.round
      ..strokeJoin=StrokeJoin.round
      ..style=PaintingStyle.stroke;
    if(t==ReaderInkTool.highlighter)p.blendMode=BlendMode.multiply;
    return p;
  }

  @override
  void paint(Canvas c,Size s){
    for(final e in strokes){
      if(e.length<2)continue;
      var t=ReaderInkTool.pen;
      var col=Colors.red;
      var w=2.6;
      var opacity=1.0;
      var start=0;
      if(e.length>=5&&e.first.dx>size.width*.99&&e.first.dy>size.height*.99){
        t=ReaderInkTool.values[(e[1].dx/size.width*10).round().clamp(0,2).toInt()];
        col=Color(((e[2].dx/size.width).clamp(0.0,1.0)*0xffffffff).round());
        w=(e[3].dx/size.width).clamp(.001,1.0)*100;
        opacity=(e[4].dx/size.width).clamp(.05,1.0);
        start=5;
      }
      _drawPath(c,e.sublist(start),_paint(t,col,w,opacity));
    }
    // The active stroke is drawn directly, without persistence metadata.
    // This prevents the metadata sentinel from becoming a visible diagonal
    // line from the lower-right corner to the first pen point.
    if(current.length>=2&&tool!=ReaderInkTool.eraser){
      final opacity=tool==ReaderInkTool.highlighter?.28:1.0;
      _drawPath(c,current,_paint(tool,color,width,opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old)=>old.strokes!=strokes||old.current!=current||old.tool!=tool||old.color!=color||old.width!=width||old.size!=size;
}
