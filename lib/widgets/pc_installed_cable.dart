import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Installed connector backs: contacts are inside the socket, not exposed.
void paintInstalledCable(
  Canvas canvas,
  Path route,
  double progress,
  int contacts,
  Color signalColor,
  double scale,
) {
  final metric = route.computeMetrics().first;
  final distance = metric.length * progress.clamp(0.0, 1.0);
  final tangent = metric.getTangentForOffset(distance);
  if (tangent == null) return;
  final ribbon = contacts == 7 || contacts == 15;
  final count = contacts == 24
      ? 12
      : contacts == 8
      ? 4
      : contacts == 4
      ? 4
      : 2;
  final pitch = 1.8 * scale;
  final width = ribbon ? (contacts == 7 ? 5 : 10) * scale : count * pitch;
  final visible = metric.extractPath(0, distance);
  canvas.drawPath(
    visible.shift(Offset(1.5 * scale, 2 * scale)),
    Paint()
      ..color = Colors.black.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width + 3 * scale,
  );
  if (ribbon) {
    canvas.drawPath(
      visible,
      Paint()
        ..color = contacts == 7
            ? const Color(0xFF9F3026)
            : const Color(0xFF24282C)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width,
    );
    canvas.drawPath(
      visible.shift(Offset(-scale, -scale)),
      Paint()
        ..color = contacts == 7
            ? const Color(0xFFDC6250)
            : const Color(0xFF51575C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale,
    );
  } else {
    // Offset each conductor along the local curve normal so bends keep their
    // spacing instead of becoming overlapping copies of one colored line.
    for (var strand = 0; strand < count; strand++) {
      final offset = (strand - (count - 1) / 2) * pitch;
      final path = Path();
      final samples = math.max(2, (distance / (3 * scale)).ceil());
      for (var n = 0; n <= samples; n++) {
        final t = metric.getTangentForOffset(distance * n / samples)!;
        final normal = Offset(-t.vector.dy, t.vector.dx);
        final point = t.position + normal * offset;
        if (n == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      final color = contacts == 2
          ? (strand == 0 ? signalColor : const Color(0xFFE2E0D9))
          : const Color(0xFF30363C);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF101317)
          ..style = PaintingStyle.stroke
          ..strokeWidth = pitch
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = pitch * .65
          ..strokeCap = StrokeCap.round,
      );
    }
  }
  canvas.save();
  canvas.translate(tangent.position.dx, tangent.position.dy);
  // The long ATX housing lies along the vertical socket in the board artwork.
  canvas.rotate(contacts == 24 ? 0 : tangent.angle);
  canvas.scale(scale);
  final housingWidth = contacts == 24
      ? 9.0
      : ribbon
      ? 7.0
      : 9.0;
  final housingHeight = contacts == 24
      ? 30.0
      : ribbon
      ? (contacts == 15 ? 18.0 : 10.0)
      : count * 2.4 + 2;
  final rect = Rect.fromCenter(
    center: Offset.zero,
    width: housingWidth,
    height: housingHeight,
  );
  final shell = RRect.fromRectAndRadius(rect, const Radius.circular(1.3));
  canvas.drawShadow(Path()..addRRect(shell), Colors.black, 2, true);
  canvas.drawRRect(
    shell,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF616970), Color(0xFF242A30), Color(0xFF10151A)],
      ).createShader(rect),
  );
  canvas.drawRRect(
    shell,
    Paint()
      ..color = const Color(0xFF858B90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6,
  );
  for (var i = 1; i < (contacts == 24 ? 12 : count); i++) {
    final y = rect.top + housingHeight * i / (contacts == 24 ? 12 : count);
    canvas.drawLine(
      Offset(rect.left + 1, y),
      Offset(rect.right - 1, y),
      Paint()
        ..color = const Color(0xFF141A20)
        ..strokeWidth = .6,
    );
  }
  // Retention tab on power plugs; stepped strain relief on SATA plugs.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left - 2, -2.5, ribbon ? 3 : 4, 5),
      const Radius.circular(.7),
    ),
    Paint()..color = const Color(0xFF7B8288),
  );
  canvas.restore();
}
