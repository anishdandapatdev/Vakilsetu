import 'package:flutter/material.dart';

/// Scalable code-native interpretation of the generated custom legal icon family.
/// Solid fills only; raster design sheets are references, not screenshot UI.
class LegalIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const LegalIcon(
    this.name, {
    super.key,
    this.size = 28,
    this.color = const Color(0xFF637F9D),
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: name == 'brand' ? 'VakilSetu scales and bridge' : null,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LegalPainter(name, color)),
    ),
  );
}

class _LegalPainter extends CustomPainter {
  final String name;
  final Color accent;
  _LegalPainter(this.name, this.accent);
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 48, size.height / 48);
    final p = Paint()
      ..color = accent.computeLuminance() > .45
          ? const Color(0xFFE4EDF4)
          : const Color(0xFF21364B)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = accent.withValues(alpha: .22)
      ..style = PaintingStyle.fill;
    final blueFill = Paint()
      ..color = const Color(0xFF147BEA)
      ..style = PaintingStyle.fill;
    final tealFill = Paint()
      ..color = const Color(0xFF19B7B0)
      ..style = PaintingStyle.fill;
    final goldFill = Paint()
      ..color = const Color(0xFFF5B942)
      ..style = PaintingStyle.fill;
    final softFill = Paint()
      ..color = const Color(0xFFEAF7FB)
      ..style = PaintingStyle.fill;
    void path(List<Offset> points, {bool close = false, bool filled = false}) {
      final x = Path()..moveTo(points.first.dx, points.first.dy);
      for (final v in points.skip(1)) {
        x.lineTo(v.dx, v.dy);
      }
      if (close) x.close();
      if (filled) c.drawPath(x, fill);
      c.drawPath(x, p);
    }

    void line(double a, double b, double d, double e) =>
        c.drawLine(Offset(a, b), Offset(d, e), p);
    void rect(
      double x,
      double y,
      double w,
      double h, {
      bool filled = false,
      double r = 1,
    }) {
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(r),
      );
      if (filled) c.drawRRect(box, fill);
      c.drawRRect(box, p);
    }

    switch (name) {
      case 'brand':
        line(24, 7, 24, 35);
        c.drawCircle(const Offset(24, 5), 2, p);
        path([const Offset(7, 13), const Offset(24, 9), const Offset(41, 13)]);
        for (final x in [10.0, 38.0]) {
          path([
            Offset(x, 13),
            Offset(x - 6, 27),
            Offset(x + 6, 27),
          ], close: true);
          final b = Path()
            ..moveTo(x - 6, 27)
            ..quadraticBezierTo(x, 36, x + 6, 27)
            ..close();
          c.drawPath(b, fill);
          c.drawPath(b, p);
        }
        final bridge = Path()
          ..moveTo(3, 41)
          ..quadraticBezierTo(24, 25, 45, 41);
        c.drawPath(bridge, p);
        for (final x in [15.0, 21.0, 27.0, 33.0]) line(x, 35, x, 42);
        final wave = Path()
          ..moveTo(3, 45)
          ..cubicTo(18, 48, 25, 39, 45, 45);
        c.drawPath(
          wave,
          Paint()
            ..color = const Color(0xFFA08355)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke,
        );
      case 'courts':
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 3, 44, 42),
            const Radius.circular(9),
          ),
          softFill,
        );
        path(
          [const Offset(4, 16), const Offset(24, 4), const Offset(44, 16)],
          close: true,
          filled: true,
        );
        c.drawCircle(const Offset(24, 11), 2, p);
        c.drawCircle(const Offset(24, 11), 2, goldFill);
        rect(5, 39, 38, 4);
        line(8, 35, 40, 35);
        for (final x in [10.0, 22.0, 34.0]) rect(x, 20, 4, 15, filled: true);
        c.drawCircle(const Offset(5, 39), 4, tealFill);
        c.drawCircle(const Offset(43, 39), 4, tealFill);
      case 'home':
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 3, 44, 42),
            const Radius.circular(10),
          ),
          softFill,
        );
        final a = Path()
          ..moveTo(10, 42)
          ..lineTo(10, 20)
          ..quadraticBezierTo(10, 5, 24, 5)
          ..quadraticBezierTo(38, 5, 38, 20)
          ..lineTo(38, 42)
          ..close();
        c.drawPath(a, p);
        final roof = Path()
          ..moveTo(7, 18)
          ..lineTo(24, 5)
          ..lineTo(41, 18)
          ..lineTo(37, 21)
          ..lineTo(24, 11)
          ..lineTo(11, 21)
          ..close();
        c.drawPath(roof, blueFill);
        c.drawPath(roof, p);
        final b = Path()
          ..moveTo(17, 42)
          ..lineTo(17, 23)
          ..quadraticBezierTo(17, 14, 24, 14)
          ..quadraticBezierTo(31, 14, 31, 23)
          ..lineTo(31, 42)
          ..close();
        c.drawPath(b, fill);
        c.drawPath(b, p);
        line(5, 43, 43, 43);
        c.drawCircle(const Offset(27, 30), 1, p);
        c.drawCircle(const Offset(7, 40), 4, tealFill);
        c.drawCircle(const Offset(41, 40), 4, tealFill);
      case 'chats':
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 16, 30, 23),
            const Radius.circular(7),
          ),
          tealFill,
        );
        rect(15, 17, 28, 21, filled: true, r: 6);
        path([
          const Offset(37, 38),
          const Offset(40, 43),
          const Offset(40, 36),
        ]);
        final b = Path()
          ..moveTo(11, 7)
          ..lineTo(30, 7)
          ..quadraticBezierTo(36, 7, 36, 13)
          ..lineTo(36, 25)
          ..quadraticBezierTo(36, 31, 30, 31)
          ..lineTo(16, 31)
          ..lineTo(8, 38)
          ..lineTo(8, 30)
          ..quadraticBezierTo(4, 30, 4, 25)
          ..lineTo(4, 13)
          ..quadraticBezierTo(4, 7, 11, 7)
          ..close();
        c.drawPath(b, blueFill);
        c.drawPath(b, p);
        for (final x in [13.0, 20.0, 27.0])
          c.drawCircle(Offset(x, 19), 1.2, Paint()..color = Colors.white);
      case 'advocates':
        c.drawCircle(const Offset(24, 12), 8, goldFill);
        c.drawCircle(const Offset(24, 12), 8, p);
        final b = Path()
          ..moveTo(8, 43)
          ..lineTo(8, 36)
          ..quadraticBezierTo(9, 23, 24, 23)
          ..quadraticBezierTo(39, 23, 40, 36)
          ..lineTo(40, 43)
          ..close();
        c.drawPath(b, blueFill);
        c.drawPath(b, p);
        path([
          const Offset(20, 25),
          const Offset(24, 31),
          const Offset(19, 42),
          const Offset(15, 42),
          const Offset(20, 25),
        ], filled: true);
        path([
          const Offset(28, 25),
          const Offset(24, 31),
          const Offset(29, 42),
          const Offset(33, 42),
        ], filled: true);
      case 'groups':
        for (final entry in [
          (const Offset(10, 17), tealFill),
          (const Offset(38, 17), goldFill),
        ]) {
          final v = entry.$1;
          c.drawCircle(v, 5, entry.$2);
          c.drawCircle(v, 5, p);
          rect(v.dx - 7, 25, 14, 14, filled: true, r: 5);
        }
        c.drawCircle(const Offset(24, 12), 7, blueFill);
        c.drawCircle(const Offset(24, 12), 7, p);
        rect(13, 25, 22, 18, filled: true, r: 7);
      case 'documents':
        path(
          [
            const Offset(12, 4),
            const Offset(29, 4),
            const Offset(39, 15),
            const Offset(39, 44),
            const Offset(12, 44),
          ],
          close: true,
          filled: true,
        );
        path([const Offset(29, 4), const Offset(29, 15), const Offset(39, 15)]);
        for (final y in [23.0, 29.0, 35.0]) line(18, y, 32, y);
        rect(7, 24, 5, 14, filled: true);
      case 'verified':
        c.drawCircle(const Offset(24, 24), 17, fill);
        c.drawCircle(const Offset(24, 24), 17, p);
        path([
          const Offset(15, 24),
          const Offset(21, 30),
          const Offset(33, 17),
        ]);
      default:
        c.drawCircle(const Offset(24, 24), 15, p);
        line(24, 15, 24, 26);
        c.drawCircle(const Offset(24, 33), 1, p);
    }
  }

  @override
  bool shouldRepaint(covariant _LegalPainter old) =>
      old.name != name || old.accent != accent;
}
