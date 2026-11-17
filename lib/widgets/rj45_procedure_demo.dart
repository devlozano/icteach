import 'package:flutter/material.dart';

import 'rj45_art.dart';

class Rj45ProcedureDemo extends StatefulWidget {
  const Rj45ProcedureDemo({super.key});

  @override
  State<Rj45ProcedureDemo> createState() => _Rj45ProcedureDemoState();
}

class _Rj45ProcedureDemoState extends State<Rj45ProcedureDemo> {
  static const _steps = <({String title, String action, String check})>[
    (
      title: 'Measure and strip 30 mm of jacket',
      action:
          'Set the ruler to 30 mm. Lightly rotate the jacket stripper around the sheath, then slide off only the outer jacket.',
      check:
          'Acceptable training range: 25–40 mm. No conductor insulation may be nicked.',
    ),
    (
      title: 'Cut the plastic spline',
      action:
          'Spread the four twisted pairs aside and cut the cross-shaped spline close to the jacket with flush cutters.',
      check: 'Do not cut, pinch, or strip any individual conductor.',
    ),
    (
      title: 'Untwist only the required length',
      action:
          'Separate the orange, green, blue, and brown pairs. Keep each pair twisted as close to the jacket as possible.',
      check: 'Excessive untwisting reduces cable performance.',
    ),
    (
      title: 'Arrange conductors in T568B order',
      action:
          'Hold the plug with gold contacts facing you and the latch away. Arrange pins 1–8 from left to right.',
      check:
          'White/orange, orange, white/green, blue, white/blue, green, white/brown, brown.',
    ),
    (
      title: 'Trim the conductors to 12.5 mm',
      action:
          'Flatten and hold the conductors in order. Make one straight, square cut 12–13 mm from the jacket edge.',
      check: 'All eight tips must form one even line without changing order.',
    ),
    (
      title: 'Insert conductors into the RJ45 plug',
      action:
          'Push the conductors fully into their channels until every tip reaches the front stop.',
      check:
          'The cable jacket must enter the plug beneath the strain-relief tab.',
    ),
    (
      title: 'Crimp the plug completely',
      action:
          'Place the plug in the correct 8P8C die and close the crimper with steady pressure until the cycle is complete.',
      check:
          'All contacts must be level and the strain relief must grip the jacket.',
    ),
    (
      title: 'Repeat the same standard on End B',
      action:
          'For a straight-through cable, terminate End B using the same T568B order and the same measurements.',
      check: 'Inspect both plugs before connecting the tester.',
    ),
    (
      title: 'Connect MAIN and REMOTE, then test',
      action:
          'Connect one cable end to MAIN and the other to REMOTE. Run the tester and watch pins 1–8 in sequence.',
      check:
          'A straight-through cable must report 1→1 through 8→8. Re-terminate any open, reversed, or miswired pin.',
    ),
  ];

  int _step = 0;
  int _replay = 0;
  bool _playing = true;

  void _show(int value, {bool? playing}) {
    setState(() {
      _step = value.clamp(0, _steps.length - 1);
      _playing = playing ?? _playing;
      _replay++;
    });
  }

  void _advance() {
    if (!_playing || !mounted) return;
    if (_step == _steps.length - 1) {
      setState(() => _playing = false);
      return;
    }
    _show(_step + 1);
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final item = _steps[_step];
    return ColoredBox(
      color: const Color(0xFFF3F7FA),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E7490),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        key: const ValueKey('rj45-procedure-step-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF102D49),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Step ${_step + 1} of ${_steps.length} • 6-second demonstration',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(value: (_step + 1) / _steps.length),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => ClipRect(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 900,
                    height: 430,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('$_step-$_replay-$reducedMotion'),
                            tween: Tween(begin: 0, end: 1),
                            duration: reducedMotion
                                ? Duration.zero
                                : const Duration(seconds: 6),
                            onEnd: reducedMotion ? null : _advance,
                            builder: (context, progress, _) => _scene(progress),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFD8E3EA),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'PROPER PROCEDURE',
                                  style: TextStyle(
                                    color: Color(0xFF0E7490),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.action,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 16,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F7F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.verified_outlined,
                                        size: 19,
                                        color: Color(0xFF0F766E),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.check,
                                          style: const TextStyle(
                                            color: Color(0xFF134E4A),
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous procedure step',
                  onPressed: _step == 0
                      ? null
                      : () => _show(_step - 1, playing: false),
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton.filledTonal(
                  tooltip: _playing
                      ? 'Pause demonstration'
                      : 'Play demonstration',
                  onPressed: reducedMotion
                      ? null
                      : () => setState(() {
                          _playing = !_playing;
                          _replay++;
                        }),
                  icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Replay procedure step',
                  onPressed: () => _show(_step, playing: !reducedMotion),
                  icon: const Icon(Icons.replay_rounded),
                ),
                IconButton(
                  tooltip: 'Next procedure step',
                  onPressed: _step == _steps.length - 1
                      ? null
                      : () => _show(_step + 1, playing: false),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scene(double progress) {
    return Container(
      key: const ValueKey('rj45-procedure-motion'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C253B), Color(0xFF123E57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _BenchGridPainter())),
          if (_step == 0) ...[
            Rj45Art.image('cable_intact', width: 390, height: 170),
            Positioned(left: 84, bottom: 75, child: _ruler('30 mm', 250)),
            Positioned(
              left: 140 + progress * 210,
              top: 102,
              child: Rj45Art.image('stripper', width: 100, height: 78),
            ),
          ] else if (_step == 1) ...[
            Rj45Art.image('cable_spline', width: 390, height: 190),
            Positioned(
              left: 150 + progress * 155,
              top: 100,
              child: Rj45Art.image('cutters', width: 110, height: 82),
            ),
          ] else if (_step == 2) ...[
            Transform.scale(
              scale: .88 + progress * .12,
              child: Rj45Art.image('cable_pairs', width: 430, height: 210),
            ),
          ] else if (_step == 3) ...[
            Positioned(
              left: 38,
              right: 38,
              child: Row(
                children: [
                  for (final entry in const [
                    0,
                    1,
                    2,
                    5,
                    4,
                    3,
                    6,
                    7,
                  ].asMap().entries)
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          (1 - progress) * (entry.key.isEven ? 45 : -45),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Rj45Art.image(
                              Rj45Art.wire(entry.value),
                              height: 150,
                            ),
                            Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (_step == 4) ...[
            Rj45Art.image('cable_pairs', width: 410, height: 190),
            Positioned(left: 110, bottom: 70, child: _ruler('12.5 mm', 250)),
            Positioned(
              right: 70 + progress * 125,
              top: 95,
              child: Rj45Art.image('cutters', width: 110, height: 82),
            ),
          ] else if (_step == 5) ...[
            Positioned(
              left: 55 + progress * 185,
              child: Rj45Art.image('cable_pairs', width: 250, height: 170),
            ),
            Positioned(
              right: 52,
              child: Rj45Art.image('plug_empty', width: 180, height: 180),
            ),
          ] else if (_step == 6) ...[
            Rj45Art.image('cable_plug', width: 350, height: 205),
            Positioned(
              top: 55 + progress * 80,
              child: Rj45Art.image(
                progress > .72 ? 'crimper_closed' : 'crimper_open',
                width: 240,
                height: 180,
              ),
            ),
          ] else if (_step == 7) ...[
            Positioned(left: 65, child: _endCard('END A', progress)),
            Positioned(
              right: 65,
              child: _endCard('END B', (progress - .25).clamp(0, 1)),
            ),
          ] else ...[
            Positioned(
              left: 45,
              child: Rj45Art.image('tester_main', width: 190, height: 220),
            ),
            Positioned(
              right: 45,
              child: Rj45Art.image('tester_remote', width: 190, height: 220),
            ),
            Positioned(
              bottom: 55,
              child: Row(
                children: [
                  for (var pin = 0; pin < 8; pin++)
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: progress * 8 >= pin
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF475569),
                      ),
                      child: Text(
                        '${pin + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ruler(String label, double width) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7D6),
      border: Border.all(color: const Color(0xFFF4C95D), width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF713F12),
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _endCard(String label, double progress) => Transform.scale(
    scale: .88 + .12 * progress,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Rj45Art.image('cable_plug', width: 190, height: 150),
        Text(
          '$label • T568B',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _BenchGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
