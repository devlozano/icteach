import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter_svg/flutter_svg.dart';
import '../data/simulation_step_detail.dart';
import '../models/simulation_model.dart';

/// A stateful operation at the selected target, completed before awarding credit.
class SimulationStepLab extends StatefulWidget {
  const SimulationStepLab({
    super.key,
    required this.simulation,
    required this.item,
    this.onMistake,
  });
  final Simulation simulation;
  final DraggableItem item;
  final ValueChanged<String>? onMistake;
  @override
  State<SimulationStepLab> createState() => _SimulationStepLabState();
}

class _SimulationStepLabState extends State<SimulationStepLab>
    with SingleTickerProviderStateMixin {
  late final _detail = SimulationStepDetail.forItem(
    widget.simulation,
    widget.item,
  );
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  final _address = TextEditingController();
  final _mask = TextEditingController();
  int _action = 0;
  double _alignment = .15;
  bool get _alignsHardware =>
      (widget.simulation.type == 'assembly' ||
          widget.simulation.id == 'sim_coc1_cabling') &&
      widget.item.category != 'diagnostic';
  bool _busy = false, _repaired = false;
  String? _feedback;
  bool get _ip => widget.simulation.id == 'sim_coc2_ipconfig';
  bool get _fault => !_repaired && widget.item.step.isEven;
  bool get _finished => _action == _detail.actions.length;
  String get _expectedAddress => widget.item.name.split(': ').last;

  @override
  void dispose() {
    _motion.dispose();
    _address.dispose();
    _mask.dispose();
    super.dispose();
  }

  void _mistake(String message) {
    setState(() => _feedback = message);
    widget.onMistake?.call('${widget.item.name}: $message');
  }

  Future<void> _perform() async {
    if (_busy || _finished) return;
    if (_alignsHardware && _action == 2 && (_alignment - .5).abs() > .05) {
      _mistake(
        'The keys are not aligned. Adjust the part to the center marker before seating it; never force the connector.',
      );
      return;
    }
    if (_ip &&
        _action == 1 &&
        (_address.text.trim() != _expectedAddress ||
            _mask.text.trim() != '255.255.255.0')) {
      _mistake(
        'Configuration rejected. Compare this device address with the allocation plan and use the /24 mask 255.255.255.0.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      try {
        await _motion.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _action++;
    });
  }

  void _verify(bool pass) {
    if (pass && _fault) {
      _mistake(
        'This observation does not pass. Identify the mismatch, then rework this step before accepting it.',
      );
    } else if (!pass && !_fault) {
      _mistake(
        'Compare the observation with the acceptance criterion. This result meets the requested check.',
      );
    } else if (!pass) {
      setState(() {
        _repaired = true;
        _action = _detail.actions.length - 1;
        _feedback =
            'Fault identified. Repeat the final operation and inspect the new result.';
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel operation',
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Training workbench • Perform, observe, then verify.',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _action / _detail.actions.length,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SimulationOperationScene(
                    simulation: widget.simulation,
                    item: widget.item,
                    motion: _motion,
                    action: _action,
                    total: _detail.actions.length,
                    fault: _finished && _fault,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _finished
                        ? 'Inspect the result'
                        : 'Operation ${_action + 1} of ${_detail.actions.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _finished
                        ? 'Acceptance criterion: ${_detail.expected}'
                        : _detail.actions[_action],
                  ),
                  if (_alignsHardware && _action == 2) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Align the component key with the center marker before seating.',
                    ),
                    Center(
                      child: Transform.rotate(
                        angle: (_alignment - .5) * 1.8,
                        child: const Icon(Icons.memory, size: 42),
                      ),
                    ),
                    Slider(
                      key: const ValueKey('component-alignment'),
                      value: _alignment,
                      divisions: 20,
                      label: '${(_alignment * 100).round()}%',
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _alignment = value),
                    ),
                    const Center(
                      child: Text(
                        '▲ Correct alignment',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  if (_ip && _action == 1) ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('ipv4-address'),
                      controller: _address,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'IPv4 address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('ipv4-mask'),
                      controller: _mask,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Subnet mask',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_finished) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Observed in this training run: ${_fault ? _detail.fault : _detail.expected}',
                        ),
                      ),
                    ),
                  ],
                  if (_feedback != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _feedback!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (!_finished)
                    FilledButton.icon(
                      key: const ValueKey('perform-operation'),
                      onPressed: _busy ? null : _perform,
                      icon: Icon(_busy ? Icons.hourglass_top : Icons.touch_app),
                      label: Text(
                        _busy
                            ? 'Operation in progress…'
                            : _ip && _action == 1
                            ? 'Apply configuration'
                            : 'Perform operation',
                      ),
                    ),
                  if (_finished)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('rework-operation'),
                          onPressed: () => _verify(false),
                          icon: const Icon(Icons.build_outlined),
                          label: const Text('Fault found • rework'),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('accept-operation'),
                          onPressed: () => _verify(true),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Check passes • complete step'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Procedure and operation log'),
                    children: [
                      for (var i = 0; i < _detail.actions.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            i < _action
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: i < _action ? Colors.green : null,
                          ),
                          title: Text('${i + 1}. ${_detail.actions[i]}'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The same scene is used in the replayable guide and in the assessed operation.
/// Hardware moves into place, network traffic traverses its link, software
/// operations update a virtual display, and service work scans the component.
class SimulationOperationScene extends StatelessWidget {
  const SimulationOperationScene({
    super.key,
    required this.simulation,
    required this.item,
    required this.motion,
    required this.action,
    required this.total,
    this.fault = false,
  });
  final Simulation simulation;
  final DraggableItem item;
  final Animation<double> motion;
  final int action, total;
  final bool fault;

  @override
  Widget build(BuildContext context) {
    final network = simulation.competency == 'COC2';
    final software =
        simulation.id.contains('os_install') ||
        simulation.id.contains('software');
    final service =
        simulation.id.contains('maintenance') ||
        simulation.id.contains('repair');
    final removal = simulation.type == 'disassembly';
    return Semantics(
      label: '${item.name}: $action of $total operations performed',
      child: Container(
        height: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xff10243a),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedBuilder(
          animation: motion,
          builder: (context, _) {
            final progress = motion.value;
            return LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Text(
                      '${software
                          ? 'VIRTUAL CONSOLE'
                          : network
                          ? 'NETWORK LINK'
                          : service
                          ? 'SERVICE BENCH'
                          : 'COMPONENT BENCH'}  •  ${item.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Icon(
                          fault
                              ? Icons.warning_amber
                              : action == total
                              ? Icons.task_alt
                              : Icons.precision_manufacturing_outlined,
                          size: 18,
                          color: fault ? Colors.amber : Colors.cyanAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fault
                                ? 'Inspection requires attention'
                                : action == total
                                ? 'Ready for verification'
                                : 'Operation ${action + 1} / $total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (software) ...[
                    Positioned(
                      left: 16,
                      top: 44,
                      width: box.maxWidth * .28,
                      height: 100,
                      child: _asset(),
                    ),
                    Positioned(
                      left: box.maxWidth * .36,
                      right: 16,
                      top: 48,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '> ${item.correctSlot.replaceAll('_', ' ')}',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: ((action + progress) / total).clamp(0, 1),
                            color: Colors.cyanAccent,
                            backgroundColor: Colors.white12,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            action == total
                                ? 'Inspect operation result'
                                : 'Applying operation ${action + 1}…',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (network) ...[
                    Positioned(
                      left: 18,
                      top: 54,
                      width: 75,
                      height: 80,
                      child: _asset(),
                    ),
                    Positioned(
                      right: 22,
                      top: 69,
                      child: Icon(
                        Icons.hub_outlined,
                        size: 55,
                        color: fault ? Colors.amber : Colors.cyanAccent,
                      ),
                    ),
                    Positioned(
                      left: 102,
                      right: 86,
                      top: 96,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: Colors.cyanAccent,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Positioned(
                      left:
                          102 +
                          (box.maxWidth - 208).clamp(0, double.infinity) *
                              progress,
                      top: 87,
                      child: const Icon(
                        Icons.circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Positioned(
                      left: 102,
                      right: 86,
                      top: 116,
                      child: Text(
                        simulation.id.contains('ipconfig')
                            ? item.name.split(': ').last
                            : item.correctSlot.replaceAll('_', ' '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ] else ...[
                    Positioned(
                      left: box.maxWidth * .38,
                      top: 48,
                      width: box.maxWidth * .4,
                      height: 106,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.developer_board,
                            color: Colors.white24,
                            size: 72,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: service
                          ? box.maxWidth * .32
                          : box.maxWidth *
                                (.08 +
                                    .34 * (removal ? 1 - progress : progress)),
                      top: 48 + (service ? 0 : 12 * progress),
                      width: box.maxWidth * .35,
                      height: 100,
                      child: Transform.rotate(
                        angle: service ? 0 : -.12 * (1 - progress),
                        child: _asset(),
                      ),
                    ),
                    if (service)
                      Positioned(
                        left: box.maxWidth * .3 + box.maxWidth * .4 * progress,
                        top: 43,
                        height: 115,
                        width: 3,
                        child: Container(
                          color: Colors.cyanAccent.withValues(alpha: .8),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _asset() => item.imageUrl.endsWith('.svg')
      ? SvgPicture.asset(
          item.imageUrl,
          semanticsLabel: item.name,
          fit: BoxFit.contain,
        )
      : Image.asset(
          item.imageUrl,
          semanticLabel: item.name,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.memory, color: Colors.white, size: 48),
        );
}
