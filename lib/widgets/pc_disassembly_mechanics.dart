import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Anchors share the assembly artwork's normalized chassis coordinates.
const pcServicePoints = <String, List<Offset>>{
  'gpu': [Offset(.565, .595), Offset(.252, .59), Offset(.574, .625)],
  'storage': [Offset(.704, .648), Offset(.731, .51)],
  'psu': [Offset(.559, .405), Offset(.233, .8)],
  'cooler': [
    Offset(.46, .24),
    Offset(.335, .244),
    Offset(.452, .244),
    Offset(.395, .34),
  ],
  'ram': [Offset(.532, .212), Offset(.532, .517)],
  'cpu': [Offset(.437, .35), Offset(.4, .275)],
  'motherboard': [Offset(.51, .705), Offset(.267, .18), Offset(.54, .68)],
};

/// Persistent mechanical state, rather than a temporary generic action icon.
class PcDisassemblyMechanicsPainter extends CustomPainter {
  const PcDisassemblyMechanicsPainter({
    required this.release,
    required this.removed,
  });
  final Map<String, double> release;
  final Set<String> removed;
  double p(String kind, int operation) => release['$kind:$operation'] ?? 0;
  bool present(String kind) => !removed.contains('disassembly_$kind');

  @override
  void paint(Canvas canvas, Size size) {
    // A fixed drawing space keeps details aligned at every workbench size.
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 667);
    Offset point(Offset normalized) =>
        Offset(normalized.dx * 1000, normalized.dy * 667);
    void screw(Offset location, double progress) {
      final center = point(location);
      canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF090D11));
      if (progress >= 1) return;
      canvas.save();
      canvas.translate(center.dx, center.dy - 13 * progress);
      canvas.drawCircle(
        Offset(2, 3 + progress * 6),
        5,
        Paint()..color = Colors.black.withValues(alpha: .45 * (1 - progress)),
      );
      canvas.rotate(-progress * math.pi * 5);
      canvas.drawCircle(
        Offset.zero,
        4.8,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFE2E7EC), Color(0xFF59646F)],
          ).createShader(const Rect.fromLTWH(-5, -5, 10, 10)),
      );
      final groove = Paint()
        ..color = const Color(0xFF242B33)
        ..strokeWidth = 1.5;
      canvas.drawLine(const Offset(-3, 0), const Offset(3, 0), groove);
      canvas.drawLine(const Offset(0, -3), const Offset(0, 3), groove);
      canvas.restore();
    }

    void screws(List<Offset> points, double progress) {
      for (var i = 0; i < points.length; i++) {
        screw(points[i], (progress * points.length - i).clamp(0.0, 1.0));
      }
    }

    void clip(Offset location, double progress, {bool lower = false}) {
      canvas.save();
      final center = point(location);
      canvas.translate(center.dx, center.dy);
      canvas.rotate((lower ? 1 : -1) * progress * .95);
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(-4, lower ? 0 : -13, 8, 13),
        const Radius.circular(2),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFFADB5BD));
      canvas.drawRRect(
        body,
        Paint()
          ..color = const Color(0xFF40474F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset.zero,
        2,
        Paint()..color = const Color(0xFF363D44),
      );
      canvas.restore();
    }

    void lead(
      Offset start,
      Offset socket,
      double progress,
      Color color, {
      double width = 13,
      bool routeLeft = false,
    }) {
      final a = point(start);
      final end = point(socket) + Offset(20 * progress, 30 * progress);
      final bend = math.min(65.0, (a - end).distance * .32);
      final path = Path()..moveTo(a.dx, a.dy);
      if (routeLeft) {
        // Route the CPU supply around the chassis perimeter, clear of the fan.
        path.cubicTo(225, a.dy, 228, a.dy - 70, 228, 260);
        path.cubicTo(
          228,
          end.dy - 22,
          end.dx - 20,
          end.dy - 25,
          end.dx,
          end.dy,
        );
      } else {
        path.cubicTo(
          a.dx + bend,
          a.dy + bend * .3,
          end.dx + bend * .7,
          end.dy + bend * .8,
          end.dx,
          end.dy,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xAA000000)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke,
      );
      for (var i = -1; i <= 1; i++) {
        canvas.drawPath(
          path.shift(Offset(i * 1.2, 0)),
          Paint()
            ..color = i == 0 ? color : const Color(0xFF333B43)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
        );
      }
      final housing = Rect.fromCenter(center: end, width: width, height: 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(housing, const Radius.circular(1.5)),
        Paint()..color = const Color(0xFF242A30),
      );
      canvas.drawLine(
        housing.topLeft,
        housing.topRight,
        Paint()
          ..color = const Color(0xFF848D96)
          ..strokeWidth = 1.2,
      );
      if (progress > 0) {
        for (var i = 0; i < 4; i++) {
          final x = end.dx - width * .3 + i * width * .2;
          canvas.drawLine(
            Offset(x, end.dy - 4),
            Offset(x, end.dy - 4 - 3 * progress),
            Paint()
              ..color = const Color(0xFFC8B578)
              ..strokeWidth = 1,
          );
        }
      }
    }

    if (present('safety')) {
      screws(const [Offset(.217, .175), Offset(.217, .82)], p('safety', 4));
      final power = 1 - p('safety', 0);
      canvas.drawCircle(
        point(const Offset(.783, .14)),
        3,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF242B30),
            Colors.lightBlueAccent,
            power,
          )!,
      );
      lead(
        const Offset(.81, .93),
        const Offset(.79, .8),
        p('safety', 1),
        const Color(0xFF4E5862),
      );
      if (p('safety', 3) > 0) {
        canvas.drawArc(
          const Rect.fromLTWH(310, 610, 70, 28),
          0,
          math.pi * 1.7,
          false,
          Paint()
            ..color = const Color(0xFF2796D2)
            ..strokeWidth = 5
            ..style = PaintingStyle.stroke,
        );
        canvas.drawLine(
          const Offset(375, 625),
          const Offset(240, 611),
          Paint()
            ..color = const Color(0xFF2796D2)
            ..strokeWidth = 1.5,
        );
      }
      canvas.restore();
      return;
    }
    if (present('psu')) {
      // Released leads remain parked beside their sockets until the PSU leaves.
      lead(
        const Offset(.43, .82),
        const Offset(.558, .405),
        p('psu', 0),
        const Color(0xFFC9AD57),
        width: 19,
      );
      lead(
        const Offset(.435, .82),
        const Offset(.565, .595),
        p('gpu', 0),
        const Color(0xFF7E8790),
      );
      lead(
        const Offset(.445, .82),
        const Offset(.69, .65),
        p('storage', 0),
        const Color(0xFF9B5447),
        width: 16,
      );
      lead(
        const Offset(.445, .81),
        const Offset(.287, .16),
        p('psu', 0),
        const Color(0xFFB7A162),
        width: 10,
        routeLeft: true,
      );
      screws(const [
        Offset(.235, .78),
        Offset(.235, .91),
        Offset(.442, .78),
        Offset(.442, .91),
      ], p('psu', 1));
    }
    if (present('motherboard')) {
      lead(
        const Offset(.545, .68),
        const Offset(.717, .65),
        p('storage', 0),
        const Color(0xFFB24D3C),
        width: 9,
      );
    }
    if (present('storage')) {
      screws(const [Offset(.662, .505), Offset(.737, .633)], p('storage', 1));
    }
    if (present('gpu')) {
      screws(const [Offset(.253, .575), Offset(.253, .65)], p('gpu', 1));
    }
    if (present('motherboard')) {
      clip(const Offset(.575, .625), p('gpu', 2), lower: true);
      clip(const Offset(.532, .216), p('ram', 0));
      clip(const Offset(.532, .516), p('ram', 1), lower: true);
      screws(const [
        Offset(.266, .18),
        Offset(.549, .18),
        Offset(.549, .433),
        Offset(.266, .433),
        Offset(.266, .693),
        Offset(.549, .693),
      ], p('motherboard', 1));
      lead(
        const Offset(.71, .705),
        const Offset(.508, .704),
        p('motherboard', 0),
        const Color(0xFF677A8B),
        width: 9,
      );
    }
    if (present('cooler')) {
      lead(
        const Offset(.448, .30),
        const Offset(.46, .235),
        p('cooler', 0),
        const Color(0xFF8E9A78),
        width: 7,
      );
      screws(const [Offset(.335, .244), Offset(.452, .444)], p('cooler', 1));
      screws(const [Offset(.452, .244), Offset(.335, .444)], p('cooler', 2));
    } else if (present('cpu')) {
      // Used thermal compound is visible once the heatsink is lifted away.
      canvas.drawOval(
        Rect.fromCenter(
          center: point(const Offset(.393, .34)),
          width: 30,
          height: 24,
        ),
        Paint()..color = const Color(0xAAABB0B4),
      );
    }
    if (!present('cooler') && present('motherboard')) {
      final pivot = point(const Offset(.433, .394));
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(p('cpu', 0) * .95);
      canvas.drawLine(
        Offset.zero,
        const Offset(0, -60),
        Paint()
          ..color = const Color(0xFFB6C1CA)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
      final plate = Rect.fromLTWH(
        352,
        180 - 27 * p('cpu', 1),
        80,
        82 * (1 - .85 * p('cpu', 1)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(3)),
        Paint()
          ..color = const Color(0xFF8C979F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PcDisassemblyMechanicsPainter oldDelegate) =>
      true;
}
