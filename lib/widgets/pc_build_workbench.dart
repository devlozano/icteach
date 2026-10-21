import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/pc_build_procedure.dart';
import '../models/simulation_model.dart';

/// A persistent chassis shared by the build and detailed wiring practicals.
/// Only a completed physical procedure may commit an assessment item.
class PcBuildWorkbench extends StatefulWidget {
  const PcBuildWorkbench({
    super.key,
    required this.items,
    required this.completed,
    required this.onCompleteStep,
    required this.onMistake,
    this.cabling = false,
    this.locked = false,
  });
  final List<DraggableItem> items;
  final Set<String> completed;
  final bool Function(String id) onCompleteStep;
  final ValueChanged<String> onMistake;
  final bool cabling, locked;
  @override
  State<PcBuildWorkbench> createState() => _PcBuildWorkbenchState();
}

class _PcBuildWorkbenchState extends State<PcBuildWorkbench>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  final _record = TextEditingController();
  final _zoom = TransformationController();
  final _seated = <String>{};
  final _history = <String>[];
  int _operation = 0, _turns = 1;
  String? _tool, _feedback;
  bool _busy = false;
  DraggableItem? get _current {
    final pending =
        widget.items
            .where((i) => i.isRequired && !widget.completed.contains(i.id))
            .toList()
          ..sort((a, b) => a.step.compareTo(b.step));
    return pending.firstOrNull;
  }

  List<PcBuildOperation> get _steps =>
      PcBuildProcedure.operations[_current?.id] ?? const [];
  PcBuildOperation? get _step =>
      _operation < _steps.length ? _steps[_operation] : null;
  bool get _diagnostic => _current?.category == 'diagnostic';
  bool get _powered => _history.any((s) => s.startsWith('POST:'));

  @override
  void dispose() {
    _motion.dispose();
    _record.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _mistake(String message) {
    setState(() => _feedback = message);
    widget.onMistake(message);
  }

  Future<void> _act({String? dropped}) async {
    final item = _current;
    final step = _step;
    if (_busy || widget.locked || item == null || step == null) return;
    if (_tool != step.tool) {
      _mistake('Use ${step.tool} for this operation.');
      return;
    }
    if (step.place && dropped != item.id) {
      _mistake('Select the compatible ${item.name} from the parts tray.');
      return;
    }
    if (step.place && _turns % 4 != 0) {
      _mistake(
        'The key or marked corner is reversed. Rotate the part to match the socket; do not force it.',
      );
      return;
    }
    if (_diagnostic &&
        _operation == _steps.length - 1 &&
        _record.text.trim().length < 12) {
      _mistake(
        'Enter a service record describing the observed POST and inspection result.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _motion.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      if (step.place) _seated.add(item.id);
      _history.add(step.result.isEmpty ? step.label : step.result);
      if (_diagnostic && _operation == _steps.length - 1) {
        _history.add('Service record: ${_record.text.trim()}');
      }
      _operation++;
      _busy = false;
    });
    _motion.reset();
    if (_operation == _steps.length) {
      if (widget.onCompleteStep(item.id) && mounted) {
        setState(() {
          _operation = 0;
          _tool = null;
          _turns = 1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final controls = _controls();
      final scene = _scene();
      if (box.maxWidth < 600) {
        return Column(
          children: [
            Expanded(child: scene),
            SizedBox(height: box.maxHeight * .43, child: controls),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: (box.maxWidth * .28).clamp(210, 310),
            child: controls,
          ),
          const SizedBox(width: 8),
          Expanded(child: scene),
        ],
      );
    },
  );

  Widget _controls() {
    final item = _current;
    final step = _step;
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.cabling ? 'WIRE & COMMISSION' : 'BUILD A WORKING COMPUTER',
              style: const TextStyle(
                color: Color(0xff087f8c),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item?.name ?? 'Build complete',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Training kit: DDR4 desktop • 2.5-inch SATA SSD. Use the actual manufacturer manual when servicing other hardware.',
              style: TextStyle(fontSize: 11),
            ),
            if (item != null && step != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _operation / _steps.length),
              const SizedBox(height: 8),
              Text(
                'Operation ${_operation + 1} / ${_steps.length}',
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                step.label,
                key: const ValueKey('build-instruction'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('build-tool-${item.id}'),
                initialValue: _tool,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tool in hand',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: PcBuildProcedure.tools
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: _busy || widget.locked
                    ? null
                    : (v) => setState(() => _tool = v),
              ),
              const SizedBox(height: 10),
              Text(
                step.place
                    ? 'Rotate the part to match the gold corner marker, then drag it onto the highlighted socket.'
                    : 'Touch the highlighted fastener, latch or connector on the chassis.',
                style: const TextStyle(fontSize: 12),
              ),
              if (step.place) ...[
                const SizedBox(height: 8),
                Draggable<String>(
                  data: item.id,
                  maxSimultaneousDrags: _busy || widget.locked ? 0 : 1,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _part(item, size: 110),
                  ),
                  childWhenDragging: Opacity(opacity: .25, child: _part(item)),
                  child: _part(item),
                ),
                TextButton.icon(
                  key: const ValueKey('rotate-build-part'),
                  onPressed: _busy || widget.locked
                      ? null
                      : () => setState(() => _turns = (_turns + 1) % 4),
                  icon: const Icon(Icons.rotate_right),
                  label: const Text('Rotate 90°'),
                ),
                for (final other in widget.items.where((i) => !i.isRequired))
                  Draggable<String>(
                    data: other.id,
                    maxSimultaneousDrags: _busy || widget.locked ? 0 : 1,
                    feedback: Material(
                      child: SizedBox(
                        width: 100,
                        child: Image.asset(other.imageUrl),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Image.asset(other.imageUrl, width: 40),
                      title: Text(
                        other.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      subtitle: const Text('Alternative part'),
                    ),
                  ),
              ],
              if (_diagnostic && _powered) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('build-service-record'),
                  controller: _record,
                  enabled: !_busy && !widget.locked,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Service record',
                    hintText:
                        'Record detected hardware, fan operation and inspection findings.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _feedback!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Job sheet'),
              children: [
                for (final i in widget.items.where((i) => i.isRequired))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      widget.completed.contains(i.id)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(i.name),
                  ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Operation log (${_history.length})'),
              children: [
                for (final entry in _history.reversed)
                  ListTile(
                    dense: true,
                    title: Text(entry, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _part(DraggableItem item, {double size = 100}) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Positioned.fill(
          child: RotatedBox(
            quarterTurns: _turns,
            child: Image.asset(item.imageUrl, fit: BoxFit.contain),
          ),
        ),
        Align(
          alignment: [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomRight,
            Alignment.bottomLeft,
          ][_turns % 4],
          child: const Icon(
            Icons.arrow_drop_down,
            color: Colors.amber,
            size: 24,
          ),
        ),
      ],
    ),
  );

  Widget _scene() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: ColoredBox(
      color: const Color(0xff101e2b),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _powered
                        ? 'POWER ON • POST MONITOR'
                        : 'POWER ISOLATED • ESD WORKBENCH',
                    style: TextStyle(
                      color: _powered ? Colors.greenAccent : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Reset workbench zoom',
                  onPressed: () => _zoom.value = Matrix4.identity(),
                  icon: const Icon(
                    Icons.center_focus_strong,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              transformationController: _zoom,
              minScale: 1,
              maxScale: 3,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1672 / 941,
                  child: LayoutBuilder(
                    builder: (context, size) => AnimatedBuilder(
                      animation: _motion,
                      builder: (context, _) =>
                          _chassis(size.maxWidth, size.maxHeight),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_powered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xff07120e),
              child: Text(
                _history.lastWhere((s) => s.startsWith('POST:')),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.greenAccent,
                  fontSize: 12,
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              'Pinch to inspect • drag to seat • touch a hotspot to service',
              style: TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _chassis(double w, double h) {
    final item = _current, step = _step;
    final t = Curves.easeInOut.transform(_motion.value);
    final installed = {
      ...widget.completed,
      ..._seated,
      if (widget.cabling) ...PcBuildProcedure.rects.keys,
    };
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/simulations/pc-case-workbench-realistic.png',
            fit: BoxFit.fill,
          ),
        ),
        for (final entry in PcBuildProcedure.rects.entries)
          if (installed.contains(entry.key) ||
              (_busy && step?.place == true && item?.id == entry.key))
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                entry.value.left * w,
                entry.value.top * h -
                    (_busy && step?.place == true && item?.id == entry.key
                        ? (1 - t) * h * .12
                        : 0),
                entry.value.width * w,
                entry.value.height * h,
              ),
              child: Image.asset(
                'assets/simulations/${PcBuildProcedure.assets[entry.key]}',
                fit: BoxFit.fill,
              ),
            ),
        // Seated wires remain in the chassis; each circuit follows its own route.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BuildMechanicsPainter(
                installed,
                _history,
                item?.id,
                _operation,
                t,
                _busy,
                widget.cabling,
              ),
            ),
          ),
        ),
        if (step != null)
          Positioned(
            left: (step.point.dx * w - 24).clamp(0, math.max(0, w - 48)),
            top: (step.point.dy * h - 24).clamp(0, math.max(0, h - 48)),
            width: 48,
            height: 48,
            child: step.place
                ? DragTarget<String>(
                    onWillAcceptWithDetails: (_) => !_busy && !widget.locked,
                    onAcceptWithDetails: (details) =>
                        _act(dropped: details.data),
                    builder: (context, candidates, rejected) => Container(
                      key: const ValueKey('build-drop-target'),
                      decoration: BoxDecoration(
                        color: candidates.isEmpty
                            ? Colors.teal.withValues(alpha: .3)
                            : Colors.amber.withValues(alpha: .5),
                        border: Border.all(color: Colors.amber, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Align(
                        alignment: Alignment.topLeft,
                        child: Icon(Icons.arrow_drop_down, color: Colors.amber),
                      ),
                    ),
                  )
                : Semantics(
                    label: step.label,
                    button: true,
                    child: Tooltip(
                      message: step.label,
                      child: InkWell(
                        key: const ValueKey('build-hotspot'),
                        onTap: _busy || widget.locked ? null : _act,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.teal.withValues(alpha: .55),
                            border: Border.all(
                              color: Colors.cyanAccent,
                              width: 2,
                            ),
                          ),
                          child: Transform.rotate(
                            angle: _busy && step.tool == PcBuildProcedure.driver
                                ? t * math.pi * 4
                                : 0,
                            child: Transform.scale(
                              scale:
                                  _busy && step.tool != PcBuildProcedure.driver
                                  ? 1 + .2 * math.sin(t * math.pi)
                                  : 1,
                              child: Icon(
                                step.tool == PcBuildProcedure.driver
                                    ? Icons.add
                                    : step.tool == PcBuildProcedure.inspect
                                    ? Icons.search
                                    : Icons.touch_app,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}

class _BuildMechanicsPainter extends CustomPainter {
  _BuildMechanicsPainter(
    this.installed,
    this.history,
    this.current,
    this.operation,
    this.motion,
    this.busy,
    this.cabling,
  );
  final Set<String> installed;
  final List<String> history;
  final String? current;
  final int operation;
  final double motion;
  final bool busy, cabling;
  @override
  void paint(Canvas canvas, Size size) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    void wire(bool shown, Offset end, Color color, {Offset? start}) {
      if (!shown) return;
      final from = start ?? p(.43, .83);
      final routeX = from.dy < size.height * .35
          ? size.width * .47
          : size.width * .61;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(routeX, from.dy)
        ..lineTo(routeX, end.dy)
        ..lineTo(end.dx, end.dy);
      paint.strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        path,
        paint
          ..color = Colors.black
          ..strokeWidth = 6,
      );
      canvas.drawPath(
        path,
        paint
          ..color = color
          ..strokeWidth = 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: end, width: 12, height: 8),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }

    final testing = current == 'assembly_test'
        ? operation
        : installed.contains('assembly_test')
        ? 10
        : 0;
    wire(
      installed.contains('power_cable') || testing > 0,
      p(.56, .40),
      Colors.orange,
    );
    wire(
      installed.contains('cpu_power') || testing > 1,
      p(.29, .18),
      Colors.amber,
    );
    wire(
      installed.contains('gpu_power') || testing > 2,
      p(.56, .60),
      Colors.yellow,
    );
    wire(
      installed.contains('sata_cable') || testing > 3,
      p(.69, .58),
      Colors.redAccent,
      start: p(.54, .65),
    );
    wire(
      testing > 4 ||
          (current == 'cable_inspection' && operation > 0) ||
          installed.contains('cable_inspection'),
      p(.73, .58),
      Colors.orangeAccent,
    );
    wire(
      installed.contains('front_panel') || testing > 5,
      p(.51, .68),
      Colors.blueAccent,
      start: p(.77, .20),
    );
    wire(
      installed.contains('cpu_fan') || cabling,
      p(.48, .23),
      Colors.grey,
      start: p(.40, .30),
    );
    if (current == 'motherboard' || installed.contains('motherboard')) {
      const holes = [
        Offset(.28, .20),
        Offset(.54, .68),
        Offset(.54, .20),
        Offset(.28, .68),
      ];
      for (var i = 0; i < holes.length; i++) {
        if (installed.contains('motherboard') || operation > i + 1) {
          final center = p(holes[i].dx, holes[i].dy);
          canvas.drawCircle(
            center,
            4,
            Paint()
              ..color = installed.contains('motherboard') || operation > i + 6
                  ? Colors.grey
                  : Colors.amber,
          );
          canvas.drawLine(
            center - const Offset(2, 0),
            center + const Offset(2, 0),
            Paint()..color = Colors.black,
          );
        }
      }
    }
    if (current == 'cpu' && operation > 0 && operation < 5) {
      final progress = operation == 4 && busy ? 1 - motion : 1.0;
      canvas.drawLine(
        p(.43, .38),
        p(.43 + progress * .035, .29),
        paint
          ..color = Colors.grey
          ..strokeWidth = 3,
      );
      if (operation >= 2 && operation < 4) {
        canvas.drawRect(
          Rect.fromPoints(p(.36, .21), p(.42, .28)),
          paint..color = Colors.blueGrey,
        );
      }
    }
    if (current == 'cpu_fan' &&
        operation >= 2 &&
        !installed.contains('cpu_fan')) {
      canvas.drawOval(
        Rect.fromCenter(center: p(.39, .34), width: 10, height: 6),
        Paint()..color = Colors.grey.shade300,
      );
    }
    if (current == 'ram' && operation > 0 && operation < 3) {
      canvas.drawLine(
        p(.53, .22),
        p(.55, .20),
        paint
          ..color = Colors.white
          ..strokeWidth = 3,
      );
      if (operation > 1) canvas.drawLine(p(.53, .51), p(.55, .53), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BuildMechanicsPainter oldDelegate) => true;
}
