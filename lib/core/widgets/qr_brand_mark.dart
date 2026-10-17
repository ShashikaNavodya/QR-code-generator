import 'package:flutter/material.dart';

class QrBrandMark extends StatelessWidget {
  const QrBrandMark({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: QrBrandMarkPainter()),
    );
  }
}

class QrBrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 48;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * scale
      ..shader = const LinearGradient(
        colors: [Color(0xFF19D9D0), Color(0xFF388BFF), Color(0xFF9A4BFF)],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, 12 * scale, ringPaint);
    final corePaint = Paint()..color = const Color(0xFF54DAFF);
    canvas.drawCircle(center, 4 * scale, corePaint);
    final tailPaint = Paint()
      ..color = const Color(0xFF9A4BFF)
      ..strokeWidth = 5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + Offset(8 * scale, 8 * scale),
      center + Offset(16 * scale, 16 * scale),
      tailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
