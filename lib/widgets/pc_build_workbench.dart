import 'pc_installed_cable.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/pc_build_procedure.dart';
import '../models/simulation_model.dart';
import 'installed_dimm.dart';

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
  bool _busy = false, _rearView = false;
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
  bool get _powered =>
      _history.any((s) => s.startsWith('POST:') || s.startsWith('CHECK:'));

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
    final expectedDrop = item.id == 'front_panel'
        ? PcBuildProcedure.frontPanelDropTokens[_operation] ?? item.id
        : item.id;
    if (step.place && dropped != expectedDrop) {
      _mistake(
        item.id == 'front_panel' && expectedDrop != item.id
            ? 'That lead does not match these F_PANEL pins. Follow the wire color and connector label.'
            : 'Select the compatible ${item.name} from the parts tray.',
      );
      return;
    }
    if (step.place && expectedDrop == item.id && _turns % 4 != 0) {
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
    if (step.place) {
      _motion.duration = PcBuildProcedure.installDuration(item.id);
    }
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
    final frontPanelToken = item?.id == 'front_panel'
        ? PcBuildProcedure.frontPanelDropTokens[_operation]
        : null;
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.cabling
                  ? 'PC WIRING PRACTICAL'
                  : 'BUILD A WORKING COMPUTER',
              style: const TextStyle(
                color: Color(0xff087f8c),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item?.name ??
                  (widget.cabling ? 'Wiring complete' : 'Build complete'),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffe6f7f8),
                    border: Border.all(color: const Color(0xff86cbd0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FIT CHECK — confirm before seating',
                        style: TextStyle(
                          color: Color(0xff075e66),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final check
                          in PcBuildProcedure.fitChecks[item.id] ??
                              const <String>[])
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.adjust,
                                size: 13,
                                color: Color(0xff087f8c),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  check,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (step.place) ...[
                const SizedBox(height: 8),
                if (frontPanelToken != null)
                  _frontPanelLeadTray(frontPanelToken)
                else ...[
                  Draggable<String>(
                    data: item.id,
                    maxSimultaneousDrags: _busy || widget.locked ? 0 : 1,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _part(item, size: 110),
                    ),
                    childWhenDragging: Opacity(
                      opacity: .25,
                      child: _part(item),
                    ),
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
                ],
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

  Widget _frontPanelLeadTray(String expected) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'F_PANEL LEADS â€” match label, wire color and pin pair',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < PcBuildProcedure.frontPanelLeadNames.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Draggable<String>(
            data: PcBuildProcedure.frontPanelLeadNames.keys.elementAt(i),
            maxSimultaneousDrags: _busy || widget.locked ? 0 : 1,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 190,
                height: 50,
                child: _FrontPanelLeadSprite(index: i),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: .25,
              child: _frontPanelLeadTile(i, expected),
            ),
            child: _frontPanelLeadTile(i, expected),
          ),
        ),
    ],
  );

  Widget _frontPanelLeadTile(int index, String expected) {
    final token = PcBuildProcedure.frontPanelLeadNames.keys.elementAt(index);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: token == expected
            ? const Color(0xffe6f7f8)
            : const Color(0xfff4f6f8),
        border: Border.all(
          color: token == expected
              ? const Color(0xff087f8c)
              : const Color(0xffcbd5e1),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 42,
            child: _FrontPanelLeadSprite(index: index),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              PcBuildProcedure.frontPanelLeadNames[token]!,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
                    _rearView
                        ? 'REAR PANEL • EXTERNAL PORTS AND PSU'
                        : _powered
                        ? widget.cabling
                              ? 'WIRING CHECK COMPLETE'
                              : 'POWER ON • POST MONITOR'
                        : 'POWER ISOLATED • ESD WORKBENCH',
                    style: TextStyle(
                      color: _powered ? Colors.greenAccent : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('rotate-system-unit'),
                  tooltip: _rearView
                      ? 'Rotate to open side'
                      : 'Rotate to rear panel',
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _rearView = !_rearView;
                          _zoom.value = Matrix4.identity();
                        }),
                  icon: Icon(
                    _rearView ? Icons.rotate_left : Icons.rotate_right,
                    color: Colors.cyanAccent,
                    size: 22,
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
                    builder: (context, size) => AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 520),
                      transitionBuilder: (child, animation) => AnimatedBuilder(
                        animation: animation,
                        child: child,
                        builder: (context, child) => Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0012)
                            ..rotateY((1 - animation.value) * math.pi / 2),
                          child: child,
                        ),
                      ),
                      child: _rearView
                          ? Image.asset(
                              'assets/simulations/pc-case-rear-panel-v2.png',
                              key: const ValueKey('system-unit-rear'),
                              width: size.maxWidth,
                              height: size.maxHeight,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            )
                          : AnimatedBuilder(
                              key: const ValueKey('system-unit-open-side'),
                              animation: _motion,
                              builder: (context, _) =>
                                  _chassis(size.maxWidth, size.maxHeight),
                            ),
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
                _history.lastWhere(
                  (s) => s.startsWith('POST:') || s.startsWith('CHECK:'),
                ),
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
              'Pinch to inspect • rotate for rear panel • drag connectors to seat',
              style: TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _componentLayer(String id, double progress, bool installing) {
    final asset = 'assets/simulations/${PcBuildProcedure.assets[id]}';
    if (id == 'ssd') {
      return Opacity(
        opacity: installing ? 1 - progress : 0,
        child: Image.asset(asset, fit: BoxFit.fill),
      );
    }
    if (id != 'ram' && id != 'gpu') {
      return RotatedBox(
        quarterTurns: PcBuildProcedure.quarterTurns(id),
        child: Image.asset(asset, fit: BoxFit.fill),
      );
    }
    final seatedOpacity = installing ? progress : 1.0;
    final installedAsset = PcBuildProcedure.installedAssets[id]!;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (installing)
          Opacity(
            opacity: 1 - progress,
            child: Transform.scale(
              scaleX: id == 'ram' ? 3.8 - 2.8 * progress : 1,
              scaleY: id == 'gpu' ? 2.2 - 1.2 * progress : 1,
              child: RotatedBox(
                quarterTurns: id == 'ram' ? 1 : 0,
                child: Image.asset(asset, fit: BoxFit.fill),
              ),
            ),
          ),
        Opacity(
          opacity: seatedOpacity,
          child: id == 'ram'
              ? const InstalledDimm()
              : Image.asset(
                  'assets/simulations/$installedAsset',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
        ),
      ],
    );
  }

  List<(Offset, int)> _visibleFasteners(
    Set<String> installed,
    String? current,
    int operation,
  ) {
    final result = <(Offset, int)>[];
    for (final entry in PcBuildProcedure.fasteners.entries) {
      final id = entry.key;
      final complete = installed.contains(id);
      // The completed photo layers already contain their final mounting
      // detail. A separate screw sprite should only appear during the active
      // installation operation, never float over the finished chassis.
      if (complete || current != id) continue;
      for (var i = 0; i < entry.value.length; i++) {
        var visible = false;
        var sprite = id == 'gpu' || id == 'psu' ? 1 : 0;
        if (id == 'motherboard') {
          final boardPlaced =
              operation > PcBuildProcedure.placementOperation[id]!;
          if (!boardPlaced && operation > i + 1) {
            visible = true;
            sprite = 2;
          } else if (boardPlaced && operation > 11 + i) {
            visible = true;
          }
        } else {
          final firstScrew = switch (id) {
            'cpu_fan' || 'gpu' => 4,
            'ssd' => 2,
            'psu' => 3,
            _ => 999,
          };
          visible = operation >= firstScrew + i;
        }
        if (visible) result.add((entry.value[i], sprite));
      }
    }
    return result;
  }

  Offset? _cableEndpoint(String id, int operation) => switch (id) {
    'power_cable' => const Offset(.501, .338),
    'cpu_power' => const Offset(.326, .187),
    'gpu_power' => const Offset(.455, .58),
    'sata_cable' => const Offset(.635, .315),
    'sata_power' => const Offset(.675, .315),
    'front_panel' => switch (operation) {
      1 => const Offset(.49, .68),
      2 => const Offset(.505, .69),
      3 => const Offset(.495, .685),
      4 => const Offset(.475, .675),
      5 => const Offset(.485, .68),
      _ => null,
    },
    _ => null,
  };

  Widget _cableSeatAnimation(
    DraggableItem item,
    int operation,
    double progress,
    double w,
    double h,
  ) {
    final end = _cableEndpoint(item.id, operation)!;
    final start = item.id == 'front_panel'
        ? const Offset(.77, .22)
        : const Offset(.68, .78);
    final position = Offset.lerp(
      start,
      end,
      Curves.easeInOutCubic.transform(progress),
    )!;
    final extent = 112 - 64 * progress;
    final leadIndex = item.id == 'front_panel' && operation >= 2
        ? operation - 2
        : null;
    return Positioned(
      left: position.dx * w - extent / 2,
      top: position.dy * h - extent / 2,
      width: extent,
      height: extent,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: (1 - progress) * -.18,
          child: Opacity(
            opacity: .72 + .28 * progress,
            child: leadIndex == null
                ? Image.asset(
                    item.imageUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )
                : _FrontPanelLeadSprite(index: leadIndex),
          ),
        ),
      ),
    );
  }

  Widget _chassis(double w, double h) {
    final item = _current, step = _step;
    final mount = item == null || !PcBuildProcedure.rects.containsKey(item.id)
        ? null
        : PcBuildProcedure.targetRect(item.id);
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
                entry.value.left * w +
                    (_busy && step?.place == true && item?.id == entry.key
                        ? PcBuildProcedure.installStartOffset(entry.key).dx *
                              w *
                              (1 - t)
                        : 0),
                entry.value.top * h +
                    (_busy && step?.place == true && item?.id == entry.key
                        ? PcBuildProcedure.installStartOffset(entry.key).dy *
                              h *
                              (1 - t)
                        : 0),
                entry.value.width * w,
                entry.value.height * h,
              ),
              child: Transform.rotate(
                angle: (_busy && step?.place == true && item?.id == entry.key
                    ? PcBuildProcedure.installStartAngle(entry.key) * (1 - t)
                    : 0),
                child: Transform.scale(
                  scale: (_busy && step?.place == true && item?.id == entry.key
                      ? PcBuildProcedure.installStartScale(entry.key) +
                            (1 -
                                    PcBuildProcedure.installStartScale(
                                      entry.key,
                                    )) *
                                t
                      : 1),
                  child: _componentLayer(
                    entry.key,
                    t,
                    _busy && step?.place == true && item?.id == entry.key,
                  ),
                ),
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
        for (final fastener in _visibleFasteners(
          installed,
          item?.id,
          _operation,
        ))
          Positioned(
            left: fastener.$1.dx * w - 7,
            top: fastener.$1.dy * h - 7,
            width: 14,
            height: 14,
            child: IgnorePointer(child: _FastenerSprite(index: fastener.$2)),
          ),
        if (_busy &&
            step?.place == true &&
            item != null &&
            _cableEndpoint(item.id, _operation) != null)
          _cableSeatAnimation(item, _operation, t, w, h),
        if (step != null)
          Positioned(
            left: step.place && mount != null
                ? mount.left * w
                : (step.point.dx * w - 24).clamp(0, math.max(0, w - 48)),
            top: step.place && mount != null
                ? mount.top * h
                : (step.point.dy * h - 24).clamp(0, math.max(0, h - 48)),
            width: step.place && mount != null ? mount.width * w : 48,
            height: step.place && mount != null ? mount.height * h : 48,
            child: step.place
                ? DragTarget<String>(
                    onWillAcceptWithDetails: (_) => !_busy && !widget.locked,
                    onAcceptWithDetails: (details) =>
                        _act(dropped: details.data),
                    builder: (context, candidates, rejected) => Container(
                      key: const ValueKey('build-drop-target'),
                      decoration: BoxDecoration(
                        color: candidates.isEmpty
                            ? Colors.transparent
                            : Colors.amber.withValues(alpha: .22),
                        border: Border.all(
                          color: candidates.isEmpty
                              ? Colors.transparent
                              : Colors.amber,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
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

class _FrontPanelLeadSprite extends StatelessWidget {
  const _FrontPanelLeadSprite({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Align(
      alignment: Alignment(0, -1 + index * (2 / 3)),
      heightFactor: .25,
      child: Image.asset(
        'assets/simulations/cable-front-panel-leads-v2.png',
        width: 190,
        fit: BoxFit.fitWidth,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}

class _FastenerSprite extends StatelessWidget {
  const _FastenerSprite({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    if (index == 2) {
      return Semantics(
        label: 'Brass motherboard standoff',
        image: true,
        child: const CustomPaint(painter: _MotherboardStandoffPainter()),
      );
    }
    return ClipRect(
      child: Align(
        alignment: Alignment(index - 1.0, 0),
        widthFactor: 1 / 3,
        child: Image.asset(
          'assets/simulations/assembly-fastener-heads-v2.png',
          height: 14,
          fit: BoxFit.fitHeight,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _MotherboardStandoffPainter extends CustomPainter {
  const _MotherboardStandoffPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .42;
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 6 + i * math.pi / 3;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        hex.moveTo(point.dx, point.dy);
      } else {
        hex.lineTo(point.dx, point.dy);
      }
    }
    hex.close();
    canvas.drawShadow(hex, Colors.black, 1.5, true);
    canvas.drawPath(
      hex,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Color(0xFFFFE19A), Color(0xFFC58A28), Color(0xFF73501B)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..color = const Color(0xFF6E4815)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      radius * .34,
      Paint()..color = const Color(0xFF34220F),
    );
    canvas.drawCircle(
      center.translate(-.45, -.45),
      radius * .17,
      Paint()..color = const Color(0xFFC18A36),
    );
  }

  @override
  bool shouldRepaint(covariant _MotherboardStandoffPainter oldDelegate) =>
      false;
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
    void fastener(Offset center, bool secured, {double radius = 5}) {
      // Screw heads are rendered by _FastenerSprite at the same calibrated
      // anchor. Drawing another generic circle here created a doubled screw.
    }

    void latch(Offset center, bool open, {bool vertical = false}) {
      final delta = vertical
          ? Offset(open ? 7 : 0, 0)
          : Offset(0, open ? -7 : 0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center + delta,
            width: vertical ? 6 : 16,
            height: vertical ? 16 : 6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = open ? Colors.amber : const Color(0xffd6dde3),
      );
    }

    final placementIndex = current == null
        ? null
        : PcBuildProcedure.placementOperation[current!];
    if (current != null &&
        placementIndex == operation &&
        !installed.contains(current)) {
      final target = PcBuildProcedure.targetRect(current!);
      final targetRect = Rect.fromLTWH(
        target.left * size.width,
        target.top * size.height,
        target.width * size.width,
        target.height * size.height,
      );
      final pulse = busy ? .35 + .25 * math.sin(motion * math.pi) : .28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(targetRect, const Radius.circular(5)),
        Paint()..color = Colors.cyanAccent.withValues(alpha: pulse),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(targetRect, const Radius.circular(5)),
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      const corner = 12.0;
      final guide = Paint()
        ..color = Colors.white
        ..strokeWidth = 2;
      for (final pair in [
        (targetRect.topLeft, const Offset(1, 1)),
        (targetRect.topRight, const Offset(-1, 1)),
        (targetRect.bottomLeft, const Offset(1, -1)),
        (targetRect.bottomRight, const Offset(-1, -1)),
      ]) {
        canvas.drawLine(
          pair.$1,
          pair.$1 + Offset(pair.$2.dx * corner, 0),
          guide,
        );
        canvas.drawLine(
          pair.$1,
          pair.$1 + Offset(0, pair.$2.dy * corner),
          guide,
        );
      }
      if (current == 'ram') {
        final seated = PcBuildProcedure.rects['ram']!;
        final slot = Rect.fromLTWH(
          seated.left * size.width,
          seated.top * size.height,
          seated.width * size.width,
          seated.height * size.height,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(slot.inflate(2), const Radius.circular(2)),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          Offset(slot.left - 4, slot.center.dy),
          Offset(slot.right + 4, slot.center.dy),
          Paint()
            ..color = Colors.black
            ..strokeWidth = 3,
        );
      } else {
        for (final point
            in PcBuildProcedure.fasteners[current!] ?? const <Offset>[]) {
          canvas.drawCircle(
            p(point.dx, point.dy),
            4,
            Paint()
              ..color = Colors.white70
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
    void wire(
      bool shown,
      Offset end,
      Color color, {
      Offset? start,
      double? viaX,
      double progress = 1,
      int contacts = 2,
    }) {
      if (!shown) return;
      final from = start ?? p(.345, .83);
      final routeX =
          viaX ??
          (from.dy < size.height * .35 ? size.width * .47 : size.width * .61);
      final bendY = from.dy + (end.dy - from.dy) * .55;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          from.dx + (routeX - from.dx) * .55,
          from.dy,
          routeX,
          from.dy + (bendY - from.dy) * .45,
          routeX,
          bendY,
        )
        ..cubicTo(
          routeX,
          end.dy - (end.dy - bendY) * .35,
          end.dx + (routeX - end.dx) * .35,
          end.dy,
          end.dx,
          end.dy,
        );
      paintInstalledCable(
        canvas,
        path,
        progress,
        contacts,
        color,
        size.width / 1000,
      );
    }

    final testing = current == 'assembly_test'
        ? operation
        : installed.contains('assembly_test')
        ? 10
        : 0;
    wire(
      installed.contains('power_cable') ||
          testing > 0 ||
          (current == 'power_cable' && operation == 2 && busy),
      p(.501, .338),
      Colors.orange,
      progress: current == 'power_cable' && operation == 2 && busy ? motion : 1,
      contacts: 24,
    );
    wire(
      installed.contains('cpu_power') ||
          testing > 1 ||
          (current == 'cpu_power' && operation == 2 && busy),
      p(.326, .187),
      Colors.amber,
      viaX: size.width * .235,
      progress: current == 'cpu_power' && operation == 2 && busy ? motion : 1,
      contacts: 8,
    );
    wire(
      installed.contains('gpu_power') ||
          testing > 2 ||
          (current == 'gpu_power' && operation == 2 && busy),
      p(.455, .58),
      Colors.yellow,
      progress: current == 'gpu_power' && operation == 2 && busy ? motion : 1,
      contacts: 8,
    );
    wire(
      installed.contains('sata_cable') ||
          testing > 3 ||
          (current == 'sata_cable' && operation == 1 && busy),
      p(.635, .315),
      Colors.redAccent,
      start: p(.501, .585),
      progress: current == 'sata_cable' && operation == 1 && busy ? motion : 1,
      contacts: 7,
    );
    wire(
      installed.contains('sata_power') ||
          testing > 4 ||
          (current == 'sata_power' && operation == 2 && busy),
      p(.675, .315),
      Colors.orangeAccent,
      progress: current == 'sata_power' && operation == 2 && busy ? motion : 1,
      contacts: 15,
    );
    final frontPanelComplete =
        (installed.contains('front_panel') && current != 'front_panel') ||
        testing > 5;
    wire(
      frontPanelComplete ||
          (current == 'front_panel' &&
              (operation > 2 || operation == 2 && busy)),
      p(.505, .69),
      Colors.blueAccent,
      start: p(.77, .20),
      viaX: size.width * .73,
      progress: current == 'front_panel' && operation == 2 && busy ? motion : 1,
    );
    wire(
      frontPanelComplete ||
          (current == 'front_panel' &&
              (operation > 3 || operation == 3 && busy)),
      p(.495, .685),
      Colors.deepOrangeAccent,
      start: p(.77, .205),
      viaX: size.width * .735,
      progress: current == 'front_panel' && operation == 3 && busy ? motion : 1,
    );
    wire(
      frontPanelComplete ||
          (current == 'front_panel' &&
              (operation > 4 || operation == 4 && busy)),
      p(.475, .675),
      Colors.redAccent,
      start: p(.77, .21),
      viaX: size.width * .74,
      progress: current == 'front_panel' && operation == 4 && busy ? motion : 1,
    );
    wire(
      frontPanelComplete ||
          (current == 'front_panel' &&
              (operation > 5 || operation == 5 && busy)),
      p(.485, .68),
      Colors.greenAccent,
      start: p(.77, .215),
      viaX: size.width * .745,
      progress: current == 'front_panel' && operation == 5 && busy ? motion : 1,
    );
    wire(
      installed.contains('cpu_fan') || cabling,
      p(.455, .23),
      Colors.grey,
      start: p(.40, .30),
      contacts: 4,
    );
    if (current == 'motherboard' || installed.contains('motherboard')) {
      final holes = PcBuildProcedure.fasteners['motherboard']!;
      final boardPlaced =
          installed.contains('motherboard') ||
          operation > PcBuildProcedure.placementOperation['motherboard']!;
      for (var i = 0; i < holes.length; i++) {
        if (installed.contains('motherboard') || operation > i + 1) {
          final center = p(holes[i].dx, holes[i].dy);
          final secured =
              installed.contains('motherboard') || operation > 11 + i;
          if (boardPlaced) {
            fastener(center, secured, radius: 4);
          }
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
      latch(p(.456, .211), true);
      latch(p(.456, .474), operation > 1);
    }
    if ((current == 'gpu' && operation >= 2) || installed.contains('gpu')) {
      final seated = installed.contains('gpu') || operation >= 3;
      latch(p(.455, .51), !seated, vertical: true);
      final screws = PcBuildProcedure.fasteners['gpu']!;
      for (var i = 0; i < screws.length; i++) {
        if (installed.contains('gpu') || operation >= i + 4) {
          fastener(p(screws[i].dx, screws[i].dy), true, radius: 4);
        }
      }
    }
    if (current == 'ssd' || installed.contains('ssd')) {
      final screws = PcBuildProcedure.fasteners['ssd']!;
      for (var i = 0; i < screws.length; i++) {
        if (installed.contains('ssd') || operation >= i + 2) {
          fastener(p(screws[i].dx, screws[i].dy), true, radius: 4);
        }
      }
    }
    if (current == 'psu' || installed.contains('psu')) {
      final screws = PcBuildProcedure.fasteners['psu']!;
      for (var i = 0; i < screws.length; i++) {
        if (installed.contains('psu') || operation >= i + 3) {
          fastener(p(screws[i].dx, screws[i].dy), true, radius: 4);
        }
      }
    }
    if (current == 'cpu_fan' || installed.contains('cpu_fan')) {
      final coolerScrews = PcBuildProcedure.fasteners['cpu_fan']!;
      for (var i = 0; i < coolerScrews.length; i++) {
        if (installed.contains('cpu_fan') || operation >= i + 4) {
          fastener(
            p(coolerScrews[i].dx, coolerScrews[i].dy),
            true,
            radius: 3.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BuildMechanicsPainter oldDelegate) => true;
}
