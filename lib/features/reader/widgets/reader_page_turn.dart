import 'package:flutter/material.dart';

/// Standalone page-turn animation implementation.
///
/// Keep navigation, gestures, PDF loading, TOC and reader state outside this
/// file. Mount this widget from the reader integration point when ready.
/// direction: +1 = next page, -1 = previous page.
class ReaderPageTurn extends StatelessWidget {
  const ReaderPageTurn({super.key,required this.child,required this.pageKey,required this.direction,this.duration=const Duration(milliseconds:260)});
  final Widget child;
  final int pageKey;
  final int direction;
  final Duration duration;
  @override Widget build(BuildContext context){
    final begin=Offset(direction>=0?1:-1,0);
    final rotationBegin=direction>=0?0.045:-0.045;
    return AnimatedSwitcher(duration:duration,reverseDuration:duration,switchInCurve:Curves.easeOutCubic,switchOutCurve:Curves.easeInCubic,layoutBuilder:(current,previous)=>Stack(fit:StackFit.expand,children:[...previous,?current]),transitionBuilder:(animated,animation){final slide=Tween<Offset>(begin:begin,end:Offset.zero).chain(CurveTween(curve:Curves.easeOutCubic));final rotation=Tween<double>(begin:rotationBegin,end:0).chain(CurveTween(curve:Curves.easeOutCubic));return FadeTransition(opacity:animation,child:SlideTransition(position:animation.drive(slide),child:AnimatedBuilder(animation:animation,child:animated,builder:(context,child)=>Transform(alignment:direction>=0?Alignment.centerRight:Alignment.centerLeft,transform:Matrix4.identity()..setEntry(3,2,.001)..rotateY(rotation.evaluate(animation)),child:child))));},child:KeyedSubtree(key:ValueKey<int>(pageKey),child:child));
  }
}
