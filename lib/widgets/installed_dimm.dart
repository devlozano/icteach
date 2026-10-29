import 'package:flutter/material.dart';

/// Tight edge-on DIMM layer. The original bitmap had a large opaque canvas,
/// which reduced the actual module to less than one pixel at workbench scale.
class InstalledDimm extends StatelessWidget {
  const InstalledDimm({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'RAM seated vertically in the DDR4 slot',
    image: true,
    child: const CustomPaint(
      key: ValueKey('installed-ram-dimm'),
      painter: _InstalledDimmPainter(),
    ),
  );
}

class _InstalledDimmPainter extends CustomPainter {
  const _InstalledDimmPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .13,
        size.height * .035,
        size.width * .74,
        size.height * .93,
      ),
      Radius.circular(size.width * .16),
    );
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 2, true);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF111820), Color(0xFF38434C), Color(0xFF10161C)],
        ).createShader(body.outerRect),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .43,
        size.height * .065,
        size.width * .14,
        size.height * .87,
      ),
      Paint()..color = const Color(0xFF176B3A),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .47,
        size.height * .49,
        size.width * .06,
        size.height * .035,
      ),
      Paint()..color = const Color(0xFFD8B84D),
    );
    final accent = Paint()
      ..color = const Color(0xFF2389FF)
      ..strokeWidth = (size.width * .08).clamp(1.0, 2.2)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .72, size.height * .18),
      Offset(size.width * .72, size.height * .39),
      accent,
    );
    canvas.drawLine(
      Offset(size.width * .72, size.height * .61),
      Offset(size.width * .72, size.height * .82),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _InstalledDimmPainter oldDelegate) => false;
}
