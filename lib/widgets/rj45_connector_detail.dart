import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/rj45_session.dart';

/// Contact-side view, latch behind, cable entering below. Uses the learner's
/// actual pin assignments, never a prefilled correct answer.
class Rj45ConnectorDetail extends StatelessWidget {
  const Rj45ConnectorDetail({super.key, required this.end, this.progress = 1});
  final CableEnd end;
  final double progress;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'RJ45 contact-side inspection. Pins one to eight, left to right. Latch behind. ' +
        List.generate(
          8,
          (i) =>
              'Pin ' +
              (i + 1).toString() +
              ': ' +
              (end.pins[i] == null
                  ? 'empty'
                  : Rj45Session.colors[end.pins[i]!]),
        ).join(', '),
    child: CustomPaint(
      painter: _ConnectorPainter(
        List.of(end.pins),
        end.seated,
        end.stage == CableStage.finished,
        progress,
        DefaultTextStyle.of(context).style.fontFamily,
      ),
      size: Size.infinite,
    ),
  );
}

class _ConnectorPainter extends CustomPainter {
  final List<int?> pins;
  final bool seated, crimped;
  final double progress;
  final String? fontFamily;
  _ConnectorPainter(
    this.pins,
    this.seated,
    this.crimped,
    this.progress,
    this.fontFamily,
  );
  static const colors = [
    Color(0xFFF59E0B),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFF3B82F6),
    Color(0xFFB77945),
    Color(0xFFB77945),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 600, size.height / 300);
    canvas.translate(
      (size.width - 600 * scale) / 2,
      (size.height - 300 * scale) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()..isAntiAlias = true;
    void rect(Rect rect, Color color, [double radius = 0]) {
      paint
        ..style = PaintingStyle.fill
        ..color = color
        ..shader = null;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }

    void line(Offset a, Offset b, Color color, double width) {
      paint
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = width
        ..shader = null;
      canvas.drawLine(a, b, paint);
    }

    void text(
      String value,
      double x,
      double y, {
      Color color = const Color(0xFFDBEAFE),
      double font = 12,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: font,
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }

    // Fine inspection grid.
    for (double x = 0; x < 600; x += 20)
      line(Offset(x, 0), Offset(x, 300), const Color(0xFF193C54), .5);
    for (double y = 0; y < 300; y += 20)
      line(Offset(0, y), Offset(600, y), const Color(0xFF193C54), .5);
    // Rear latch, visible through the clear moulded shell.
    rect(const Rect.fromLTWH(280, 92, 40, 140), const Color(0xFF4B6A7F), 7);
    rect(const Rect.fromLTWH(284, 166, 32, 52), const Color(0xFF89A6B6), 5);
    final shell = const Rect.fromLTWH(196, 38, 208, 182);
    paint
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Color(0xAADEEFFF), Color(0x335B91AF), Color(0x999FC2D7)],
      ).createShader(shell);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shell, const Radius.circular(12)),
      paint,
    );
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFB5D9EF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shell, const Radius.circular(12)),
      paint,
    );
    // Separate wire channels and copper contact blades.
    final advance = seated ? (crimped ? 0.0 : 1 - progress) : 1.0;
    for (var i = 0; i < 8; i++) {
      final x = 216.0 + i * 24;
      rect(Rect.fromLTWH(x - 8, 52, 16, 139), const Color(0x333C6C8A), 3);
      line(Offset(x - 10, 51), Offset(x - 10, 181), const Color(0x559AC0D6), 1);
      final wire = pins[i];
      if (wire != null) {
        final top = 76 + advance * 98;
        final path = Path()
          ..moveTo(285 + i * 4, 282)
          ..cubicTo(285 + i * 4, 229, x, 222, x, top);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = colors[wire];
        canvas.drawPath(path, paint);
        if (wire.isEven) {
          paint
            ..strokeWidth = 4
            ..color = Colors.white;
          canvas.drawPath(path, paint);
        }
        line(Offset(x, top), Offset(x, top + 3), const Color(0xFFFFBC78), 4);
      }
      final contact = Rect.fromLTWH(
        x - 6,
        51 + (crimped ? progress * 6 : 0),
        12,
        35,
      );
      paint
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          colors: [Color(0xFF8D5B12), Color(0xFFFFE29A), Color(0xFFBA852C)],
        ).createShader(contact);
      canvas.drawRRect(
        RRect.fromRectAndRadius(contact, const Radius.circular(2)),
        paint,
      );
      paint.shader = null;
      text((i + 1).toString(), x - 4, 18, font: 14);
    }
    // Jacket enters the strain relief after insertion.
    final jacketTop = seated ? 209 + (1 - progress) * 40 : 265.0;
    final jacket = Rect.fromLTWH(278, jacketTop, 44, 300 - jacketTop);
    paint
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Color(0xFF334155), Color(0xFF94A3B8), Color(0xFF475569)],
      ).createShader(jacket);
    canvas.drawRRect(
      RRect.fromRectAndRadius(jacket, const Radius.circular(8)),
      paint,
    );
    paint.shader = null;
    rect(const Rect.fromLTWH(205, 192, 190, 12), const Color(0x887CA3B9), 3);
    for (var i = 0; i < 4; i++)
      line(
        Offset(206, 204 + i * 3.0),
        Offset(394, 204 + i * 3.0),
        const Color(0xFF93B4C8),
        .8,
      );
    text('8P8C / RJ45', 22, 30, font: 17);
    text('GOLD CONTACTS', 430, 61);
    line(
      const Offset(404, 66),
      const Offset(424, 66),
      const Color(0xFF7DD3FC),
      1,
    );
    text('WIRE CHANNELS', 430, 130);
    line(
      const Offset(404, 135),
      const Offset(424, 135),
      const Color(0xFF7DD3FC),
      1,
    );
    text('STRAIN RELIEF', 430, 200);
    line(
      const Offset(397, 202),
      const Offset(424, 202),
      const Color(0xFF7DD3FC),
      1,
    );
    text('Contact side', 22, 250);
    text('Latch behind', 22, 270);
    if (crimped) {
      // Jaws close, press the contacts, then withdraw.
      final squeeze = math.sin(progress * math.pi);
      rect(
        Rect.fromLTWH(182 - 35 * (1 - squeeze), 39, 14, 170),
        const Color(0xFF64748B),
        4,
      );
      rect(
        Rect.fromLTWH(404 + 35 * (1 - squeeze), 39, 14, 170),
        const Color(0xFF64748B),
        4,
      );
      text('CRIMPED', 440, 260, color: const Color(0xFF6EE7B7), font: 15);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) => true;
}
