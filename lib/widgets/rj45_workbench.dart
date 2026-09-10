import 'rj45_art.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/rj45_session.dart';

class Rj45Workbench extends StatefulWidget {
  final void Function(int, int, bool) onComplete;
  final ValueChanged<List<String>>? onFeedback;
  const Rj45Workbench({super.key, required this.onComplete, this.onFeedback});
  @override
  State<Rj45Workbench> createState() => _Rj45WorkbenchState();
}

class _Rj45WorkbenchState extends State<Rj45Workbench> {
  Rj45Session? session;
  int active = 0, lit = -1, revision = 0;
  bool testing = false, tested = false;
  Timer? timer;
  final List<String> attempts = [];
  CableEnd get end => session!.ends[active];
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void change(VoidCallback action) => setState(() {
    action();
    revision++;
  });
  void testCable() {
    if (!session!.readyToTest || testing || tested) return;
    setState(() {
      testing = true;
      lit = -1;
    });
    timer = Timer.periodic(const Duration(milliseconds: 450), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => lit++);
      if (lit == 7) {
        t.cancel();
        setState(() {
          testing = false;
          tested = true;
        });
        final s = session!;
        attempts.add(
          '${s.kind.name}: main-to-remote ${s.wireMap.join(", ")}; ${s.passed ? "PASS" : "FAIL"}',
        );
        widget.onFeedback?.call(List.of(attempts));
      }
    });
  }

  void showReference() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Wiring reference'),
      content: const SingleChildScrollView(
        child: Text(
          'Use a compatible unshielded Cat6 cable with spline and a closed-end 8P8C plug approved for its conductor size. Follow the plug manufacturer strip and trim lengths.\n\nPin view: gold contacts facing you, latch away, cable entering from below. Pins 1–8 run left to right.\n\nT568B: white/orange, orange, white/green, blue, white/blue, green, white/brown, brown.\n\nT568A: white/green, green, white/orange, blue, white/blue, orange, white/brown, brown.\n\nStraight-through: A/A or B/B.\nCrossover (10/100BASE-TX): A/B or B/A. This is not the four-pair gigabit crossover exercise.\n\nMaintain pair twists as close to the termination as possible. Do not strip individual conductor insulation. A basic LED tester shows continuity; it cannot certify Cat6 performance or reliably detect split pairs. The final training inspection also checks standard pair assignments.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to work'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RJ45 cable workshop',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prepare and terminate both ends. Test your own wiring.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final kind in CableKind.values)
                    FilledButton(
                      onPressed: () =>
                          setState(() => session = Rj45Session(kind)),
                      child: Text(
                        kind == CableKind.straight
                            ? 'Straight-through'
                            : 'Crossover (10/100)',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final s = session!;
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.kind == CableKind.straight
                      ? 'Straight-through • A/A or B/B'
                      : 'Crossover • A/B or B/A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Wiring reference',
                onPressed: showReference,
                icon: const Icon(Icons.menu_book_outlined),
              ),
              IconButton(
                tooltip: 'Start a new cable',
                onPressed: testing
                    ? null
                    : () => setState(() {
                        session = null;
                        active = 0;
                        tested = false;
                        lit = -1;
                      }),
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final work = s.prepared ? testerPanel() : preparationPanel();
              if (constraints.maxWidth < 500) {
                return SingleChildScrollView(
                  child: SizedBox(height: 600, child: work),
                );
              }
              return work;
            },
          ),
        ),
      ],
    );
  }

  Widget preparationPanel() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 170,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < 2; i++)
                ListTile(
                  dense: true,
                  selected: active == i,
                  title: Text('Cable end ${i == 0 ? "A" : "B"}'),
                  subtitle: Text(
                    session!.ends[i].stage == CableStage.finished
                        ? 'Crimped'
                        : 'Not finished',
                  ),
                  onTap: () => change(() => active = i),
                ),
              const Divider(),
              draggable('stripper', 'Jacket stripper', Icons.content_cut),
              draggable('cutters', 'Flush cutters', Icons.cut),
              draggable('crimper', 'RJ45 crimper', Icons.handyman),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Drag the tool onto the cable. Keep the cable disconnected from powered equipment.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${math.min(end.stage.index + 1, 7)}/7 • ${stageTitle()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(instruction()),
                    ),
                    DragTarget<String>(
                      onWillAcceptWithDetails: (d) =>
                          ['stripper', 'cutters', 'crimper'].contains(d.data),
                      onAcceptWithDetails: (d) =>
                          change(() => end.tool(d.data)),
                      builder: (context, candidates, rejected) => Container(
                        key: const ValueKey('cable-work-area'),
                        height: MediaQuery.sizeOf(context).width >= 900
                            ? 220
                            : 140,
                        decoration: BoxDecoration(
                          color: candidates.isEmpty
                              ? const Color(0xff10283f)
                              : const Color(0xff234d65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('$active-$revision'),
                          tween: Tween(begin: 0, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 650),
                          builder: (context, value, _) => cableArt(value),
                        ),
                      ),
                    ),
                    if (end.stage == CableStage.untwist)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (var p = 0; p < 4; p++)
                            OutlinedButton(
                              onPressed: end.separatedPairs.contains(p)
                                  ? null
                                  : () => change(() => end.untwist(p)),
                              child: Text(
                                'Untwist ${["orange", "green", "blue", "brown"][p]} pair',
                              ),
                            ),
                        ],
                      ),
                    if (end.stage == CableStage.arrange) ...[
                      const Text(
                        'Drag each conductor to a pin. Tap a filled pin to remove it. No wiring is graded yet.',
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final w in [5, 0, 7, 2, 4, 1, 6, 3])
                            if (!end.pins.contains(w))
                              draggable(
                                'wire:$w',
                                Rj45Session.colors[w],
                                Icons.drag_indicator,
                                color: wireColor(w),
                              ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var p = 0; p < 8; p++)
                            Expanded(
                              child: DragTarget<String>(
                                onWillAcceptWithDetails: (d) =>
                                    d.data.startsWith('wire:'),
                                onAcceptWithDetails: (d) => change(
                                  () => end.place(
                                    int.parse(d.data.split(':')[1]),
                                    p,
                                  ),
                                ),
                                builder: (context, hover, rejected) => InkWell(
                                  onTap: () => change(() => end.pins[p] = null),
                                  child: Container(
                                    key: ValueKey('wire-pin-$p'),
                                    height: 78,
                                    margin: const EdgeInsets.all(2),
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: hover.isNotEmpty
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade100,
                                      border: Border.all(
                                        color: Colors.blueGrey,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('${p + 1}'),
                                        if (end.pins[p] != null) ...[
                                          Container(
                                            height: 14,
                                            color: wireColor(end.pins[p]!),
                                          ),
                                          Expanded(
                                            child: Text(
                                              Rj45Session.colors[end.pins[p]!],
                                              style: const TextStyle(
                                                fontSize: 9,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      FilledButton(
                        onPressed: end.pins.any((p) => p == null)
                            ? null
                            : () => change(end.finishOrder),
                        child: const Text('Keep this order and trim'),
                      ),
                    ],
                    if (end.stage == CableStage.insert)
                      Row(
                        children: [
                          Expanded(
                            child: draggable(
                              'bundle',
                              'Prepared cable end',
                              Icons.cable,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DragTarget<String>(
                              onWillAcceptWithDetails: (d) =>
                                  d.data == 'bundle',
                              onAcceptWithDetails: (_) => change(end.insert),
                              builder: (context, hover, rejected) => Container(
                                key: const ValueKey('empty-rj45'),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: hover.isEmpty
                                      ? Colors.blueGrey.shade100
                                      : Colors.cyan.shade100,
                                  border: Border.all(color: Colors.blueGrey),
                                ),
                                child: Column(
                                  children: [
                                    Rj45Art.image('plug_empty', height: 64),
                                    const Text(
                                      'Empty RJ45 plug\nDrag conductors fully inside',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (end.stage == CableStage.finished)
                      FilledButton(
                        onPressed: () => change(() => active = 1 - active),
                        child: const Text('Prepare the other end'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  String stageTitle() => [
    'Strip outer jacket',
    'Cut the spline',
    'Separate the twisted pairs',
    'Arrange the eight colors',
    'Trim conductors evenly',
    'Insert into RJ45 plug',
    'Crimp the plug',
    'End complete',
  ][end.stage.index];
  String instruction() => [
    'Drag the jacket stripper onto the intact cable. Score only the outer sheath and slide it off; do not nick the insulated conductors. Use the plug manufacturer preparation length.',
    'The plastic cross-shaped spline separates the pairs. Spread the pairs aside, then drag the flush cutters onto the cable to remove the exposed spline near the jacket without cutting any wire.',
    'Separate each of the four pairs yourself. Untwist only the exposed length needed for termination, keeping the twist close to the jacket. Leave each conductor insulation intact.',
    'Choose your color order using the reference if needed. Gold contacts face you and the latch faces away; the cable enters from below. Assign pins 1–8 from left to right.',
    'Hold all eight conductors flat in your chosen order. Drag the flush cutters onto the cable to make one even cut to the length required by the plug.',
    'Drag the prepared end into the empty plug. All eight tips must reach the front stop and the jacket must enter beneath the strain-relief tab.',
    'The conductors are seated. Drag the RJ45 crimper onto the plug to press all contacts and the jacket strain relief. A crimped plug cannot be uncrimped and reused.',
    'This end is crimped. Prepare the other end before connecting the tester.',
  ][end.stage.index];
  Widget testerPanel() {
    final s = session!;
    return SingleChildScrollView(
      child: Column(
        children: [
          const Text(
            'LAN cable tester',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Drag one cable end into MAIN and the other into REMOTE. Then run the test.',
          ),
          Row(
            children: [
              for (var e = 0; e < 2; e++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: s.ports.contains(e)
                        ? Text(
                            'End ${e == 0 ? "A" : "B"} connected',
                            textAlign: TextAlign.center,
                          )
                        : draggable(
                            'end:$e',
                            'Cable end ${e == 0 ? "A" : "B"}',
                            Icons.cable,
                          ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              for (var p = 0; p < 2; p++)
                Expanded(
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (d) =>
                        !testing && !tested && d.data.startsWith('end:'),
                    onAcceptWithDetails: (d) => change(
                      () => s.connect(int.parse(d.data.split(':')[1]), p),
                    ),
                    builder: (context, hover, rejected) => Container(
                      key: ValueKey('tester-port-$p'),
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hover.isEmpty
                            ? const Color(0xff10283f)
                            : const Color(0xff24536a),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            p == 0 ? 'MAIN' : 'REMOTE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Rj45Art.image(
                                  p == 0 ? 'tester_main' : 'tester_remote',
                                  height: 110,
                                ),
                                if (s.ports[p] != null)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Rj45Art.image(
                                      'cable_plug',
                                      width: 70,
                                      height: 55,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            s.ports[p] == null
                                ? 'Empty socket'
                                : 'End ${s.ports[p] == 0 ? "A" : "B"} plugged in',
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (s.ports[p] != null && !testing && !tested)
                            TextButton(
                              onPressed: () => change(() => s.ports[p] = null),
                              child: const Text('Unplug'),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (var pin = 1; pin <= 8; pin++)
                                Column(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      width: 15,
                                      height: 15,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            lit >= 0 &&
                                                (p == 0
                                                        ? lit + 1
                                                        : s.wireMap[lit]) ==
                                                    pin
                                            ? Colors.greenAccent
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      '$pin',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          FilledButton(
            onPressed: s.readyToTest && !testing && !tested ? testCable : null,
            child: Text(
              testing
                  ? 'Testing pin ${lit + 2 > 8 ? 8 : lit + 2}…'
                  : 'Run LAN test',
            ),
          ),
          if (tested) ...[
            Text(
              s.passed
                  ? 'PASS • Cable matches the selected standard'
                  : 'FAIL • Re-terminate the cable',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: s.passed ? Colors.green : Colors.red,
              ),
            ),
            Text(
              'Observed MAIN → REMOTE: ${s.wireMap.asMap().entries.map((e) => "${e.key + 1}→${e.value}").join("  ")}',
            ),
            Text(
              'Expected: ${s.expectedMap.asMap().entries.map((e) => "${e.key + 1}→${e.value}").join("  ")}',
            ),
            if (!s.standardEnds)
              const Text(
                'Training inspection: nonstandard color/pair assignment. Even matching LED sequences can hide split pairs. Compare both ends with T568A/T568B before making new terminations.',
              ),
            for (var e = 0; e < 2; e++)
              Text(
                'End ${e == 0 ? "A" : "B"}: ${s.ends[e].pins.map((w) => Rj45Session.colors[w!]).join(" • ")}',
              ),
            Wrap(
              spacing: 8,
              children: [
                for (var e = 0; e < 2; e++)
                  OutlinedButton(
                    onPressed: () => change(() {
                      s.reterminate(e);
                      active = e;
                      tested = false;
                      lit = -1;
                    }),
                    child: Text('Cut off plug ${e == 0 ? "A" : "B"} and retry'),
                  ),
                FilledButton(
                  onPressed: () =>
                      widget.onComplete(s.passed ? 8 : 0, 8, s.passed),
                  child: const Text('Submit result'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String artFor(String data) {
    if (data.startsWith('wire:')) {
      return Rj45Art.wire(int.parse(data.split(':')[1]));
    }
    if (data.startsWith('end:')) return 'cable_plug';
    if (data == 'bundle') return 'cable_pairs';
    if (data == 'crimper') {
      return end.stage == CableStage.finished
          ? 'crimper_closed'
          : 'crimper_open';
    }
    return data;
  }

  Widget cableArt(double value) {
    String? photo;
    if (end.stage == CableStage.jacket) photo = 'cable_intact';
    if (end.stage == CableStage.spline) photo = 'cable_spline';
    if (end.stage == CableStage.untwist && end.separatedPairs.isEmpty) {
      photo = 'cable_pairs';
    }
    if (photo != null) {
      return Opacity(opacity: .6 + .4 * value, child: Rj45Art.image(photo));
    }
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _CablePainter(end, value))),
        if (end.seated)
          Positioned(
            right: 8,
            top: 0,
            child: Rj45Art.image(
              'plug_side',
              width: 85,
              height: 52,
              label:
                  'Empty housing detail; actual wire order is shown in the workbench',
            ),
          ),
        if (end.stage == CableStage.finished)
          Positioned(
            left: 8,
            bottom: 0,
            child: Rj45Art.image('crimper_closed', width: 90, height: 60),
          ),
      ],
    );
  }

  Widget draggable(String data, String label, IconData icon, {Color? color}) =>
      Draggable<String>(
        data: data,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 190,
            child: toolChip(data, label, icon, color),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: .3,
          child: toolChip(data, label, icon, color),
        ),
        child: toolChip(data, label, icon, color),
      );
  Widget toolChip(String data, String label, IconData icon, Color? color) =>
      Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blueGrey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            data == 'bundle'
                ? SizedBox(
                    width: 44,
                    height: 32,
                    child: Column(
                      children: [
                        for (final wire in end.pins)
                          Container(
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 1),
                            color: wireColor(wire!),
                          ),
                      ],
                    ),
                  )
                : Rj45Art.image(
                    artFor(data),
                    width: 44,
                    height: 32,
                    label: label,
                  ),
            const SizedBox(width: 5),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}

Color wireColor(int w) => [
  Colors.orange,
  Colors.orange,
  Colors.green,
  Colors.green,
  Colors.blue,
  Colors.blue,
  Colors.brown,
  Colors.brown,
][w];

class _CablePainter extends CustomPainter {
  final CableEnd end;
  final double t;
  _CablePainter(this.end, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final mid = size.height / 2;
    final jacketEnd = end.stage == CableStage.jacket
        ? size.width * .85
        : end.seated
        ? size.width * .56
        : size.width * .28;
    paint.color = const Color(0xff64748b);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, mid - 26, jacketEnd, 52),
        const Radius.circular(12),
      ),
      paint,
    );
    if (end.stage == CableStage.jacket) {
      paint
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(Rect.fromLTWH(size.width * .28, mid - 29, 12, 58), paint);
      return;
    }
    if (end.stage == CableStage.spline) {
      paint
        ..color = Colors.white54
        ..strokeWidth = 9;
      canvas.drawLine(
        Offset(jacketEnd, mid),
        Offset(size.width * .8, mid),
        paint,
      );
      canvas.drawLine(
        Offset(size.width * .78, mid - 14),
        Offset(size.width * .78, mid + 14),
        paint,
      );
    }
    // The cut jacket slides away; the exposed spline falls after cutting.
    if (end.stage == CableStage.spline && t < 1) {
      paint.color = const Color(0xff64748b).withValues(alpha: 1 - t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(jacketEnd + t * 80, mid - 27, size.width * .5, 54),
          const Radius.circular(10),
        ),
        paint,
      );
    }
    if (end.stage == CableStage.untwist &&
        end.separatedPairs.isEmpty &&
        t < 1) {
      paint
        ..color = Colors.white54.withValues(alpha: 1 - t)
        ..strokeWidth = 8;
      canvas.drawLine(
        Offset(jacketEnd + 20, mid + t * 50),
        Offset(size.width * .8, mid + t * 70),
        paint,
      );
    }
    final ordered =
        end.stage.index >= CableStage.trim.index ||
        (end.stage == CableStage.arrange && end.pins.any((p) => p != null));
    final stop = end.stage.index >= CableStage.insert.index
        ? size.width * .79
        : size.width * .87;
    for (var i = 0; i < 8; i++) {
      if (ordered && end.pins[i] == null) continue;
      final wire = ordered ? end.pins[i]! : i;
      final pair = wire ~/ 2;
      final twisted =
          end.stage.index < CableStage.arrange.index &&
          !end.separatedPairs.contains(pair);
      final path = Path();
      for (var n = 0; n <= 40; n++) {
        final q = n / 40;
        final x = jacketEnd + (stop - jacketEnd) * q;
        final y = twisted
            ? mid +
                  (pair - 1.5) * 24 +
                  math.sin(q * math.pi * 8 + (wire.isEven ? 0 : math.pi)) * 6
            : mid + (i - 3.5) * 12 * q;
        if (n == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = wireColor(wire);
      canvas.drawPath(path, paint);
      if (wire.isEven) {
        paint
          ..strokeWidth = 2
          ..color = Colors.white;
        canvas.drawPath(path, paint);
      }
    }
    paint.style = PaintingStyle.fill;
    if (end.seated) {
      final plug = Rect.fromLTWH(
        size.width * .53 + (1 - t) * 20,
        mid - 53,
        size.width * .28,
        106,
      );
      paint.color = Colors.white.withValues(alpha: .25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(plug, const Radius.circular(5)),
        paint,
      );
      for (var i = 0; i < 8; i++) {
        paint.color = Colors.amber;
        canvas.drawRect(
          Rect.fromLTWH(stop - 3, mid + (i - 3.5) * 12 - 3, 10, 6),
          paint,
        );
      }
      if (end.stage == CableStage.finished) {
        paint
          ..color = Colors.redAccent
          ..strokeWidth = 8;
        canvas.drawLine(
          Offset(plug.left, mid - 58 + (1 - t) * 25),
          Offset(plug.right, mid - 58 + (1 - t) * 25),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CablePainter oldDelegate) => true;
}
