import 'package:flutter/material.dart';

import '../services/reader_search_service.dart';

/// Presentation-only search highlight overlay for the rendered PDF page.
class ReaderSearchHighlight extends StatelessWidget {
  final List<ReaderSearchHit> hits;

  const ReaderSearchHighlight({
    super.key,
    required this.hits,
  });

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _ReaderSearchHitPainter(hits),
      ),
    );
  }
}

class _ReaderSearchHitPainter extends CustomPainter {
  final List<ReaderSearchHit> hits;

  _ReaderSearchHitPainter(this.hits);

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x66FFEB3B);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFC107);

    for (final hit in hits) {
      final rect = Rect.fromLTWH(
        hit.x * size.width,
        hit.y * size.height,
        hit.width * size.width,
        hit.height * size.height,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_ReaderSearchHitPainter oldDelegate) {
    return oldDelegate.hits != hits;
  }
}
