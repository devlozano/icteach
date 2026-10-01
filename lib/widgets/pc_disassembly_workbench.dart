import 'pc_disassembly_mechanics.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/simulation_model.dart';

/// Layered hardware removal. Assessment and progress stay in the parent.
class PcDisassemblyWorkbench extends StatefulWidget {
  const PcDisassemblyWorkbench({
    super.key,
    required this.items,
    required this.removed,
    required this.tools,
    required this.onCompleteStep,
    this.locked = false,
    this.transformationController,
  });
  final List<DraggableItem> items;
  final Set<String> removed;
  final Map<String, String> tools;
  final bool Function(String itemId, String tool) onCompleteStep;
  final bool locked;
  final TransformationController? transformationController;
  @override
  State<PcDisassemblyWorkbench> createState() => _PcDisassemblyWorkbenchState();
}

class _PcDisassemblyWorkbenchState extends State<PcDisassemblyWorkbench>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  int _operation = 0;
  String? _tool;
  String? _moving;
  bool _busy = false;
  bool _servicing = false;
  bool _returning = false;
  bool _selected = false;
  final _benchKey = GlobalKey();
  final _dropPadKey = GlobalKey();
  final Map<String, GlobalKey> _partKeys = {};
  String? _dragging;
  DraggableItem? _flightItem;
  Rect? _flightFrom;
  Rect? _flightTo;
  static const _operations = <String, List<String>>{
    'safety': [
      'Shut down the computer',
      'Switch off PSU and unplug mains cable',
      'Hold power button to discharge residual power',
      'Connect ESD strap to the approved ground point',
      'Undo both side-panel thumbscrews',
      'Slide back and remove side panel',
    ],
    'gpu': [
      'Unplug GPU power by the connector housing',
      'Support card and undo bracket screws',
      'Press the PCIe retention latch',
    ],
    'storage': [
      'Unplug SATA data and power connectors',
      'Undo SSD mounting screws',
    ],
    'psu': [
      'Disconnect ATX, CPU and remaining power leads',
      'Support PSU and undo four chassis screws',
    ],
    'cooler': [
      'Unplug CPU fan header',
      'Loosen top-left and bottom-right fasteners',
      'Loosen top-right and bottom-left fasteners',
      'Gently twist cooler to release thermal paste',
    ],
    'ram': ['Release upper DIMM clip', 'Release lower DIMM clip'],
    'cpu': ['Release socket lever', 'Raise socket retention plate'],
    'motherboard': [
      'Disconnect front-panel, USB and fan headers',
      'Undo and collect all motherboard screws',
      'Check edges for attached cables',
    ],
    'inventory': [
      'Inspect components and socket for damage',
      'Count and label the collected fasteners',
      'Protect parts in antistatic packaging',
      'Record the completed parts inventory',
    ],
  };
  static const _rects = <String, Rect>{
    'motherboard': Rect.fromLTWH(.255, .16, .31, .55),
    'cpu': Rect.fromLTWH(.361, .29, .064, .10),
    'ram': Rect.fromLTWH(.512, .22, .043, .29),
    'cooler': Rect.fromLTWH(.326, .23, .14, .23),
    'gpu': Rect.fromLTWH(.253, .56, .33, .12),
    'storage': Rect.fromLTWH(.65, .49, .10, .16),
    'psu': Rect.fromLTWH(.227, .765, .23, .16),
  };
  static const _layers = [
    'motherboard',
    'cpu',
    'ram',
    'cooler',
    'storage',
    'psu',
    'gpu',
  ];
  String _short(String id) => id.replaceFirst('disassembly_', '');
  DraggableItem? get _current {
    final remaining =
        widget.items
            .where((i) => i.isRequired && !widget.removed.contains(i.id))
            .toList()
          ..sort((a, b) => a.step.compareTo(b.step));
    return remaining.firstOrNull;
  }

  @override
  void didUpdateWidget(covariant PcDisassemblyWorkbench oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.removed.length != widget.removed.length) {
      _operation = 0;
      _tool = null;
      _selected = false;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _act(DraggableItem item) async {
    if (_busy || widget.locked || _tool == null) return;
    if (_tool != widget.tools[item.id]) {
      widget.onCompleteStep(item.id, _tool!);
      return;
    }
    final kind = _short(item.id);
    final steps = _operations[kind] ?? const <String>[];
    if (_operation < steps.length - (_rects.containsKey(kind) ? 0 : 1)) {
      setState(() {
        _busy = true;
        _servicing = true;
      });
      final operation = steps[_operation].toLowerCase();
      _motion.duration = Duration(
        milliseconds:
            operation.contains('screw') || operation.contains('fastener')
            ? 1200
            : operation.contains('twist')
            ? 950
            : operation.contains('unplug') || operation.contains('disconnect')
            ? 800
            : 600,
      );
      if (!MediaQuery.disableAnimationsOf(context)) {
        try {
          await _motion.forward(from: 0).orCancel;
        } on TickerCanceled {
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _operation++;
        _busy = false;
        _servicing = false;
      });
      _motion.reset();
      return;
    }
    if (_rects.containsKey(kind)) return; // Released hardware must be dragged.
    _motion.duration = const Duration(milliseconds: 900);
    setState(() {
      _busy = true;
      _moving = kind;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _motion.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    widget.onCompleteStep(item.id, _tool!);
    setState(() {
      _busy = false;
      _moving = null;
      _operation = 0;
      _tool = null;
      _selected = false;
    });
    _motion.reset();
  }

  double _releaseProgress(String kind, int operation) {
    if (widget.removed.contains('disassembly_$kind')) return 1;
    if (_current?.id != 'disassembly_$kind') return 0;
    if (_operation > operation) return 1;
    if (_operation == operation && _servicing) {
      return Curves.easeInOutCubic.transform(_motion.value);
    }
    return 0;
  }

  Widget _servicePoint(DraggableItem current, Size size) {
    final points = pcServicePoints[_short(current.id)];
    if (points == null ||
        _operation >= points.length ||
        !_selected ||
        _busy ||
        _dragging != null) {
      return const SizedBox.shrink();
    }
    final point = points[_operation];
    final label = _operations[_short(current.id)]![_operation];
    return Positioned(
      left: point.dx * size.width - 18,
      top: point.dy * size.height - 18,
      width: 36,
      height: 36,
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          child: InkResponse(
            key: const ValueKey('pc-service-point'),
            onTap: widget.locked || _tool == null ? null : () => _act(current),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: .12),
                border: Border.all(color: Colors.amberAccent, width: 1.5),
              ),
              child: const Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: Colors.amberAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _canDrag(DraggableItem item) =>
      !_busy &&
      !widget.locked &&
      _current?.id == item.id &&
      _tool == widget.tools[item.id] &&
      _operation >= (_operations[_short(item.id)]?.length ?? 999) &&
      _rects.containsKey(_short(item.id));

  Rect _globalRect(GlobalKey key) {
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  Future<void> _settlePart(
    DraggableItem item,
    Offset pointer, {
    required bool accepted,
  }) async {
    if (!mounted || _busy) return;
    final source = _globalRect(_partKeys[item.id]!);
    final target = accepted ? _globalRect(_dropPadKey) : source;
    final benchOrigin = _globalRect(_benchKey).topLeft;
    final feedbackSize = _feedbackSize(item);
    final fitted = applyBoxFit(
      BoxFit.contain,
      feedbackSize,
      const Size(60, 48),
    ).destination;
    setState(() {
      _dragging = null;
      _returning = !accepted;
      _busy = true;
      _moving = _short(item.id);
      _flightItem = item;
      _flightFrom = Rect.fromCenter(
        center: pointer - benchOrigin,
        width: feedbackSize.width,
        height: feedbackSize.height,
      );
      _flightTo = Rect.fromCenter(
        center: target.center - benchOrigin,
        width: accepted ? fitted.width : source.width,
        height: accepted ? fitted.height : source.height,
      );
    });
    _motion.duration = Duration(milliseconds: accepted ? 560 : 520);
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _motion.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    final committed = accepted && widget.onCompleteStep(item.id, _tool!);
    setState(() {
      _busy = false;
      _moving = null;
      _flightItem = null;
      _flightFrom = null;
      _flightTo = null;
      if (committed) {
        _operation = 0;
        _tool = null;
        _selected = false;
      }
    });
    _motion.reset();
  }

  Size _feedbackSize(DraggableItem item) {
    final rect = _globalRect(_partKeys[item.id]!);
    final scale = math.min(1.0, 240 / math.max(rect.width, rect.height));
    return Size(rect.width * scale, rect.height * scale);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final ready = current != null && _canDrag(current);
    return LayoutBuilder(
      builder: (context, space) => Stack(
        key: _benchKey,
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: (space.maxWidth * .24).clamp(180.0, 260.0),
                child: _controls(current),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: const Color(0xFF101E2B),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            ready
                                ? 'Drag the released part into the ESD tray'
                                : 'Select a part and release its fasteners',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: InteractiveViewer(
                            transformationController:
                                widget.transformationController,
                            panEnabled: !ready && _dragging == null,
                            scaleEnabled: _dragging == null,
                            minScale: 1,
                            maxScale: 3,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: .99,
                                child: LayoutBuilder(
                                  builder: (_, viewport) => Stack(
                                    key: const ValueKey(
                                      'disassembly-case-view',
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      Positioned(
                                        left: -viewport.maxWidth * .17 / .66,
                                        top: 0,
                                        bottom: 0,
                                        width: viewport.maxWidth / .66,
                                        child: AnimatedBuilder(
                                          animation: _motion,
                                          builder: (_, _) => _scene(current),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: (space.maxWidth * .115).clamp(88.0, 144.0),
                child: _tray(),
              ),
            ],
          ),
          if (_flightItem != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (_, _) {
                    final t = Curves.easeOutCubic.transform(_motion.value);
                    final rect = Rect.lerp(_flightFrom, _flightTo, t)!;
                    return Stack(
                      children: [
                        Positioned.fromRect(
                          rect: rect.shift(
                            Offset(0, -18 * math.sin(t * math.pi)),
                          ),
                          child: Image.asset(
                            _flightItem!.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controls(DraggableItem? item) {
    if (item == null) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Disassembly complete\nAll components inventoried.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final kind = _short(item.id);
    final steps = _operations[kind] ?? const <String>[];
    final isPart = _rects.containsKey(kind);
    final ready = _operation >= steps.length;
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STEP ${item.step} / ${widget.items.where((i) => i.isRequired).length}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF087F8C)),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(item.tooltip, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('${item.id}-$_tool'),
              initialValue: _tool,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select service tools',
                isDense: true,
              ),
              items: widget.tools.values
                  .toSet()
                  .map(
                    (tool) => DropdownMenuItem(
                      value: tool,
                      child: Text(
                        tool,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _busy || _dragging != null || widget.locked
                  ? null
                  : (tool) => setState(() => _tool = tool),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      i < _operation
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: i < _operation ? Colors.teal : Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (isPart && !_selected)
              const Text(
                'Tap the highlighted part in the case to service it.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('disassembly-action'),
                onPressed:
                    _busy ||
                        widget.locked ||
                        _tool == null ||
                        (isPart && (!_selected || ready))
                    ? null
                    : () => _act(item),
                icon: Icon(
                  _busy
                      ? Icons.hourglass_top
                      : ready
                      ? Icons.open_in_new
                      : Icons.build,
                  size: 17,
                ),
                label: Text(
                  _busy
                      ? (_servicing
                            ? 'Servicing component...'
                            : _returning
                            ? 'Returning to the case...'
                            : 'Lowering into the tray...')
                      : ready
                      ? 'Drag part to the ESD tray'
                      : steps[_operation],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (kind == 'psu')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Keep the PSU enclosure sealed.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scene(DraggableItem? current) {
    final open = widget.removed.contains('disassembly_safety');
    final active = current == null ? '' : _short(current.id);
    final t = Curves.easeInOutCubic.transform(_motion.value);
    return LayoutBuilder(
      builder: (context, size) {
        Widget positioned(Rect rect, Widget child) => Positioned(
          left: rect.left * size.maxWidth,
          top: rect.top * size.maxHeight,
          width: rect.width * size.maxWidth,
          height: rect.height * size.maxHeight,
          child: child,
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/simulations/pc-case-workbench-realistic.png',
                fit: BoxFit.fill,
              ),
            ),
            for (final kind in _layers)
              if (!widget.removed.contains('disassembly_$kind'))
                positioned(
                  _rects[kind]!,
                  _component(kind, active, open, t, size.biggest),
                ),
            if (!open)
              positioned(
                const Rect.fromLTWH(.185, .012, .58, .96),
                Transform.translate(
                  offset: Offset(
                    _moving == 'safety'
                        ? -size.maxWidth *
                              (.035 * (t / .25).clamp(0.0, 1.0) +
                                  .75 * ((t - .25) / .75).clamp(0.0, 1.0))
                        : 0,
                    0,
                  ),
                  child: Opacity(
                    opacity: _moving == 'safety'
                        ? 1 - ((t - .7) / .3).clamp(0.0, 1.0)
                        : 1,
                    child: Image.asset(
                      'assets/simulations/disassembly-side-panel.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PcDisassemblyMechanicsPainter(
                    release: {
                      for (final entry in _operations.entries)
                        for (var i = 0; i < entry.value.length; i++)
                          '${entry.key}:$i': _releaseProgress(entry.key, i),
                    },
                    removed: widget.removed,
                  ),
                ),
              ),
            ),
            if (open && current != null) _servicePoint(current, size.biggest),
          ],
        );
      },
    );
  }

  Widget _component(
    String kind,
    String active,
    bool open,
    double t,
    Size sceneSize,
  ) {
    final item = widget.items.where((i) => _short(i.id) == kind).firstOrNull;
    if (item == null) return const SizedBox.shrink();
    final highlighted = open && active == kind && !_busy;
    final ready = open && _canDrag(item);
    final key = _partKeys.putIfAbsent(item.id, () => GlobalKey());
    final visual = GestureDetector(
      key: ValueKey('installed-$kind'),
      onTap: highlighted && !widget.locked && _dragging == null
          ? () {
              if (_selected && !ready) {
                _act(item);
              } else {
                setState(() => _selected = true);
              }
            }
          : null,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: highlighted
              ? Border.all(
                  color: ready
                      ? Colors.cyanAccent
                      : _selected
                      ? Colors.greenAccent
                      : Colors.amberAccent,
                  width: 2,
                )
              : null,
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: Colors.cyan.withValues(alpha: .25),
                    blurRadius: ready ? 18 : 12,
                  ),
                ]
              : null,
        ),
        child: Transform.translate(
          offset: Offset(
            0,
            kind == 'ram'
                ? -4 * _releaseProgress('ram', 1)
                : kind == 'cpu'
                ? -2 * _releaseProgress('cpu', 1)
                : 0,
          ),
          child: Transform.rotate(
            angle:
                kind == 'cooler' &&
                    active == 'cooler' &&
                    _servicing &&
                    _operation == 3
                ? .035 * math.sin(_motion.value * math.pi * 4)
                : 0,
            child: Image.asset(item.imageUrl, fit: BoxFit.fill),
          ),
        ),
      ),
    );
    return SizedBox(
      key: key,
      child: Semantics(
        label: '${item.name}${ready ? ", released; drag to ESD tray" : ""}',
        child: Opacity(
          opacity: _moving == kind ? 0 : 1,
          child: Draggable<String>(
            data: item.id,
            maxSimultaneousDrags: ready && _dragging == null ? 1 : 0,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: () => setState(() => _dragging = kind),
            onDragEnd: (details) {
              if (!details.wasAccepted && mounted) {
                _settlePart(item, details.offset, accepted: false);
              }
            },
            feedback: Builder(
              builder: (_) {
                final size = _feedbackSize(item);
                return Transform.translate(
                  offset: Offset(-size.width / 2, -size.height / 2),
                  child: Material(
                    type: MaterialType.transparency,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      builder: (_, lift, child) => Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .001)
                          ..rotateX(
                            (kind == 'cpu' || kind == 'ram' ? 0 : .10) * lift,
                          )
                          ..rotateY(
                            (kind == 'gpu' || kind == 'motherboard'
                                    ? -.08
                                    : 0) *
                                lift,
                          ),
                        child: Transform.translate(
                          offset: Offset(
                            kind == 'psu' || kind == 'storage'
                                ? -12 * (1 - lift)
                                : 0,
                            kind == 'psu' || kind == 'storage'
                                ? 0
                                : 10 * (1 - lift),
                          ),
                          child: child,
                        ),
                      ),
                      child: Container(
                        width: size.width,
                        height: size.height,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .45),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(item.imageUrl, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                );
              },
            ),
            childWhenDragging: Container(
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: .08),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: .4),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: visual,
          ),
        ),
      ),
    );
  }

  Widget _tray() => DragTarget<String>(
    key: const ValueKey('esd-tray-target'),
    onWillAcceptWithDetails: (details) {
      final item = _current;
      return item != null && item.id == details.data && _canDrag(item);
    },
    onAcceptWithDetails: (details) {
      final item = _current;
      if (item != null && item.id == details.data && _canDrag(item)) {
        _settlePart(item, details.offset, accepted: true);
      }
    },
    builder: (context, candidates, rejected) => AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: candidates.isNotEmpty
            ? const Color(0xFF145B61)
            : const Color(0xFF203746),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: candidates.isNotEmpty ? Colors.cyanAccent : Colors.white24,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'ESD TRAY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            key: _dropPadKey,
            height: 68,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  candidates.isNotEmpty
                      ? Icons.download_done
                      : Icons.move_to_inbox_outlined,
                  color: candidates.isNotEmpty
                      ? Colors.cyanAccent
                      : Colors.white54,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  candidates.isNotEmpty ? 'Release here' : 'Drop here',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                for (final item in widget.items)
                  if (widget.removed.contains(item.id) &&
                      _rects.containsKey(_short(item.id)))
                    TweenAnimationBuilder<double>(
                      key: ValueKey('stored-${_short(item.id)}'),
                      tween: Tween(begin: .96, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Tooltip(
                        message: item.name.replaceFirst('Remove ', ''),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 44,
                                child: Image.asset(item.imageUrl),
                              ),
                              Text(
                                item.name.replaceFirst('Remove ', ''),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                if (widget.removed.contains('disassembly_safety'))
                  Tooltip(
                    message: 'Collected fasteners',
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/simulations/assembly-fasteners-matched.png',
                        height: 40,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
