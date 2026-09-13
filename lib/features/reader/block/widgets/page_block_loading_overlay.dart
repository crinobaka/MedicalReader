import 'dart:math' as math;

import 'package:flutter/material.dart';

class PageBlockLoadingOverlay extends StatefulWidget {
  const PageBlockLoadingOverlay({super.key, this.message = '少女祈祷中'});

  final String message;

  @override
  State<PageBlockLoadingOverlay> createState() => _PageBlockLoadingOverlayState();
}

class _PageBlockLoadingOverlayState extends State<PageBlockLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: ColoredBox(
        color: Colors.black.withOpacity(.22),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(.96),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.rotate(
                    angle: _controller.value * math.pi * 2,
                    child: child,
                  ),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: CustomPaint(painter: _YinYangPainter()),
                  ),
                ),
                const SizedBox(height: 12),
                Text(widget.message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YinYangPainter extends CustomPainter {
  const _YinYangPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.shortestSide;
    final circle = Rect.fromCircle(center: size.center(Offset.zero), radius: d / 2);
    final black = Paint()..color = Colors.black;
    final white = Paint()..color = Colors.white;
    canvas.drawArc(circle, -math.pi / 2, math.pi, true, black);
    canvas.drawArc(circle, math.pi / 2, math.pi, true, white);
    final small = d / 4;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 - d / 4), small, white);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 + d / 4), small, black);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 - d / 4), d / 14, black);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 + d / 4), d / 14, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
