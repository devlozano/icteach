import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart' hide Simulation;
import '../models/simulation_model.dart';

/// A replayable, ungraded walkthrough built from the activity's ordered tasks.
class SimulationProcessGuide extends StatefulWidget {
  final Simulation simulation;
  const SimulationProcessGuide({super.key, required this.simulation});
  @override
  State<SimulationProcessGuide> createState() => _SimulationProcessGuideState();
}

class _SimulationProcessGuideState extends State<SimulationProcessGuide> {
  int step = 0, replay = 0;
  final Set<int> checked = {};
  List<DraggableItem> get tasks =>
      widget.simulation.items.where((i) => i.isRequired).toList()
        ..sort((a, b) => a.step.compareTo(b.step));
  String get preparation {
    final id = widget.simulation.id;
    if (id.contains('crimp')) {
      return 'Prepare cable, matching plugs, stripper, crimper, and a wire-map tester. Disconnect both ends. For T568B, verify pin orientation before ordering white-orange, orange, white-green, blue, white-blue, green, white-brown, brown.';
    }
    if (id.contains('ipconfig')) {
      return 'Record the addressing plan: PCs .10, .11, .12; server .1; router .254 on 192.168.1.0/24. Check that each address is unique and use the router as the default gateway.';
    }
    if (id.contains('topology') || id.contains('diagnostic')) {
      return 'Read the network diagram, identify source and destination, and record the reported symptom. Check physical links before addresses, routing, DNS, and application services.';
    }
    if (id.contains('os_install') || id.contains('software')) {
      return 'Confirm the approved configuration and licenses. Back up authorized data and check recovery access. Identify the correct device and destination before making changes.';
    }
    if (id.contains('identification')) {
      return 'Inspect the component image, connector shape, label, and function. Compare compatible parts before selecting a label; appearance alone is not enough.';
    }
    return 'Shut down, disconnect external power, and follow the manufacturer service and ESD procedure. Work on a clear surface, hold boards by their edges, and never open a power supply enclosure.';
  }

  String verification(DraggableItem item) {
    final id = widget.simulation.id;
    if (id.contains('crimp')) {
      return 'Check this conductor against its pin number. After all eight are aligned, trim evenly, insert fully with the jacket under the strain relief, crimp, and test both ends. A wire-map pass checks continuity and order; it does not certify cable performance.';
    }
    if (id.contains('ipconfig')) {
      return 'Confirm the address, /24 mask, gateway, and approved DNS settings. Check for duplicate addresses. Test local configuration, gateway reachability, and name resolution separately.';
    }
    if (id.contains('diagnostic') || id.contains('repair')) {
      return 'Record the observation before and after this test. Change one variable at a time. A failed test narrows the cause; it is not proof by itself. Recheck the original symptom after repair.';
    }
    if (id.contains('os_install') || id.contains('software')) {
      return 'Wait for the operation to finish, inspect its status or error message, and verify the requested setting. Restart only when required and confirm the setting remains after restart.';
    }
    if (id.contains('topology')) {
      return 'Trace the endpoint through its switch and router. Verify the intended port, link indication, and the addressing plan before testing reachability.';
    }
    if (id.contains('identification')) {
      return 'Explain the component function and name one identifying connector or marking before placing its label.';
    }
    return 'Check alignment, seating, retention, and clearance without forcing the part. Compare against the device service instructions. Complete the final visual inspection before reconnecting power and testing.';
  }

  @override
  Widget build(BuildContext context) {
    final list = tasks;
    final item = list[step];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Guided process',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close walkthrough',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(widget.simulation.title),
              const Text(
                'Practice walkthrough â€¢ Checkpoints do not change your assessment score.',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: checked.length / list.length),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Step ${step + 1} of ${list.length}: ${item.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('$step-$replay'),
                        tween: Tween(begin: 0, end: 1),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 1800),
                        builder: (context, value, child) => CustomPaint(
                          painter: _ProcessPainter(value, widget.simulation.id),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => replay++),
                        icon: const Icon(Icons.replay),
                        label: const Text('Replay demonstration'),
                      ),
                    ),
                    SizedBox(
                      height: 140,
                      child: item.imageUrl.endsWith('.svg')
                          ? SvgPicture.asset(
                              item.imageUrl,
                              semanticsLabel: item.name,
                            )
                          : Image.asset(
                              item.imageUrl,
                              semanticLabel: item.name,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.memory, size: 64),
                            ),
                    ),
                    _section('Prepare', preparation),
                    _section(
                      'Perform',
                      [
                        item.description,
                        if (item.tooltip.isNotEmpty) item.tooltip,
                        if (item.specification.isNotEmpty) item.specification,
                      ].toSet().join('\n\n'),
                    ),
                    _section('Verify before continuing', verification(item)),
                    _section(
                      'If the check fails',
                      'Stop at this step. Recheck the selected item, required resource, connection or configuration, and the previous completed step. Correct the cause before repeating the check; do not hide an error by skipping ahead.',
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: checked.contains(step),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          checked.add(step);
                        } else {
                          checked.remove(step);
                        }
                      }),
                      title: const Text(
                        'I have reviewed the action and its verification check.',
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: step == 0 ? null : () => setState(() => step--),
                    child: const Text('Previous'),
                  ),
                  const Spacer(),
                  Text('${checked.length}/${list.length} reviewed'),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: !checked.contains(step)
                        ? null
                        : () {
                            if (step < list.length - 1) {
                              setState(() => step++);
                            } else {
                              Navigator.pop(context);
                            }
                          },
                    child: Text(
                      step == list.length - 1
                          ? 'Return to activity'
                          : 'Next step',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(text),
      ],
    ),
  );
}

class _ProcessPainter extends CustomPainter {
  final double progress;
  final String id;
  _ProcessPainter(this.progress, this.id);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff2563eb);
    final y = size.height / 2;
    final network =
        id.contains('topology') ||
        id.contains('diagnostic') ||
        id.contains('ipconfig') ||
        id.contains('crimp');
    if (network) {
      paint
        ..strokeWidth = 4
        ..color = const Color(0xff94a3b8);
      canvas.drawLine(Offset(30, y), Offset(size.width - 30, y), paint);
      for (var i = 0; i < 8; i++) {
        paint.color = progress >= i / 8
            ? const Color(0xff16a34a)
            : const Color(0xffcbd5e1);
        canvas.drawCircle(Offset(30 + (size.width - 60) * i / 7, y), 9, paint);
      }
      paint.color = const Color(0xff2563eb);
      canvas.drawCircle(
        Offset(30 + (size.width - 60) * progress, y),
        13,
        paint,
      );
    } else {
      final box = Rect.fromCenter(
        center: Offset(size.width / 2, y),
        width: 130,
        height: 62,
      );
      paint.color = const Color(0xffcbd5e1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)),
        paint,
      );
      paint.color = const Color(0xff2563eb);
      final software = id.contains('os_install') || id.contains('software');
      if (software) {
        canvas.drawRect(
          Rect.fromLTWH(box.left + 8, y - 8, 114 * progress, 16),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                size.width / 2 - 90 * (1 - progress),
                y - 30 * (1 - progress),
              ),
              width: 80,
              height: 38,
            ),
            const Radius.circular(4),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ProcessPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.id != id;
}
