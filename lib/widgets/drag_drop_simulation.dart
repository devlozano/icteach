import 'simulation_process_guide.dart';
import 'summary_print_button.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/simulation_model.dart' as sim_models;
import 'draggable_item_widget.dart';
import 'drop_target_widget.dart';

class DragDropSimulation extends StatefulWidget {
  final sim_models.Simulation simulation;
  final Function(int score, int total, bool passed) onComplete;
  final ValueChanged<List<String>>? onFeedback;
  final bool practice;

  const DragDropSimulation({
    super.key,
    required this.simulation,
    required this.onComplete,
    this.onFeedback,
    this.practice = false,
  });

  @override
  State<DragDropSimulation> createState() => _DragDropSimulationState();
}

class _DragDropSimulationState extends State<DragDropSimulation> {
  late Map<String, String> _placements;
  late List<String> _availableItems;
  late List<String> _availableSlots;

  bool _isComplete = false;
  int _mistakes = 0;
  final List<String> _errorLog = [];
  int _streak = 0;
  int _xp = 0;
  bool _voiceEnabled = true;
  bool _preflightComplete = false;
  final Set<int> _safetyChecks = <int>{};
  Timer? _missionTimer;
  int _elapsedSeconds = 0;
  String? _focusedItemId;
  final TransformationController _cableZoomController =
      TransformationController();
  double _cableZoom = 1;
  int _identificationConfidence = 2;
  bool _osPreflightComplete = false;
  final Set<int> _osReadinessChecks = <int>{};
  String? _selectedResource;
  final FlutterTts _tts = FlutterTts();
  final Random _shuffleRandom = Random();

  @override
  void initState() {
    super.initState();
    _resetSimulation(notify: false);
    _configureVoice();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak('Mission started. Drag each pictured part to the correct target.');
    });
  }

  Future<void> _configureVoice() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(0.9);
  }

  Future<void> _speak(String message) async {
    if (!_voiceEnabled) return;
    await _tts.stop();
    await _tts.speak(message);
  }

  @override
  void dispose() {
    _missionTimer?.cancel();
    _cableZoomController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _resetSimulation({bool notify = true}) {
    _placements = <String, String>{};
    final shuffledItems = [...widget.simulation.items]..shuffle(_shuffleRandom);
    _availableItems = shuffledItems.map((item) => item.id).toList();
    _availableSlots = widget.simulation.slots.toList();
    _isComplete = false;
    _mistakes = 0;
    _errorLog.clear();
    _streak = 0;
    _xp = 0;
    _elapsedSeconds = 0;
    _trayPage = 0;
    _focusedItemId = null;
    _selectedResource = null;

    _missionTimer?.cancel();
    final waitingForAssemblyCheck =
        widget.simulation.id == 'sim_coc1_assembly' && !_preflightComplete;
    final waitingForOsCheck =
        widget.simulation.id == 'sim_coc1_os_install' && !_osPreflightComplete;
    if (!waitingForAssemblyCheck && !waitingForOsCheck) {
      _preflightComplete = true;
      _startTimer();
    }

    if (notify && mounted) {
      _speak('Mission reset. Try to build a perfect streak.');
      setState(() {});
    }
  }

  void _startTimer() {
    _missionTimer?.cancel();
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isComplete) setState(() => _elapsedSeconds++);
    });
  }

  void _beginAssembly() {
    if (_safetyChecks.length != 3) return;
    setState(() => _preflightComplete = true);
    _startTimer();
    _speak('Safety check complete. Begin with the motherboard.');
  }

  void _beginOsInstallation() {
    if (_osReadinessChecks.length != 3) return;
    setState(() => _osPreflightComplete = true);
    _startTimer();
    _speak('Readiness confirmed. Begin with requirements and backup.');
  }

  void _handleDrop(String itemId, String slotId) {
    if (_isComplete ||
        !_availableItems.contains(itemId) ||
        !_availableSlots.contains(slotId)) {
      return;
    }

    final item = widget.simulation.items.firstWhere(
      (simulationItem) => simulationItem.id == itemId,
    );
    final profile = _resourceProfile(item);

    if (_selectedResource != profile.$1) {
      _errorLog.add(
        'Resource selection: ${item.name} requires ${profile.$1}; use ${profile.$2}.',
      );
      setState(() {
        _mistakes++;
        _streak = 0;
        _xp = (_xp - 2).clamp(0, 9999);
      });
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF9A3412),
            duration: const Duration(seconds: 4),
            content: Text(
              'Resource check failed for ${item.name}. Required: ${profile.$1}. Fastener/control: ${profile.$2}.',
            ),
          ),
        );
      return;
    }

    if (widget.simulation.type != 'identification' &&
        widget.simulation.type != 'networking' &&
        item.step > 0 &&
        item.step != _nextAssemblyStep) {
      _errorLog.add(
        'Sequence error: attempted ${item.name} before step $_nextAssemblyStep. Complete ${_itemForStep(_nextAssemblyStep)?.name ?? 'the preceding safety step'} first.',
      );
      setState(() => _mistakes++);
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      _speak('Complete step $_nextAssemblyStep first.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Install step $_nextAssemblyStep first: '
            '${_itemForStep(_nextAssemblyStep)?.name ?? 'the next component'}.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (item.correctSlot != slotId) {
      final feedback = _compatibilityFeedback(item, slotId);
      _errorLog.add(
        'Placement/compatibility: ${item.name} → ${_slotName(slotId)}. $feedback',
      );
      setState(() {
        _mistakes++;
        _streak = 0;
        final penalty = widget.simulation.type == 'identification'
            ? _identificationConfidence * 2
            : 2;
        _xp = (_xp - penalty).clamp(0, 9999);
      });
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      _speak(feedback);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.close_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.name} is incompatible with ${_slotName(slotId)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(feedback, style: const TextStyle(fontSize: 12)),
                      if (item.specification.isNotEmpty)
                        Text(
                          item.specification,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFB42318),
            duration: const Duration(seconds: 4),
          ),
        );
      return;
    }

    setState(() {
      final existingItemId = _placements.entries
          .where((entry) => entry.value == slotId)
          .map((entry) => entry.key)
          .firstOrNull;

      if (existingItemId != null) {
        _placements.remove(existingItemId);

        if (!_availableItems.contains(existingItemId)) {
          _availableItems.add(existingItemId);
        }
      }

      _placements[itemId] = slotId;
      _availableItems.remove(itemId);
      _availableSlots.remove(slotId);
      _selectedResource = null;
      _streak++;
      _xp += widget.simulation.type == 'identification'
          ? 6 + (_identificationConfidence * 3) + (_streak > 1 ? 2 : 0)
          : 10 + (_streak > 1 ? 2 : 0);
    });

    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    _speak(
      _streak > 1
          ? 'Correct. $_streak move streak.'
          : 'Correct. ${item.name} placed.',
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF047857),
          duration: const Duration(seconds: 3),
          content: Text('Verified: ${profile.$3}'),
        ),
      );

    if (_requiredItems.every((item) => _placements.containsKey(item.id))) {
      _calculateScore();
    }
  }

  (String, String, String) _resourceProfile(sim_models.DraggableItem item) {
    if (widget.simulation.id == 'sim_coc2_crimping') {
      return (
        'RJ45 crimper + cable stripper',
        'T568B pin ${item.step} channel',
        '${item.name} is straight, fully inserted to the plug face, and remains in the required T568B order before crimping.',
      );
    }
    switch (item.id) {
      case 'motherboard':
        return (
          'Phillips #2 + ESD strap',
          'Brass standoffs + M3 screws',
          'Every board hole sits on a matching standoff; screws are snug in a cross pattern with no extra standoff underneath.',
        );
      case 'cpu':
        return (
          'ESD strap + socket retention arm',
          'Socket load plate and retention lever',
          'The corner triangle and socket keys align; the CPU lies flat without force before the retention arm is locked.',
        );
      case 'cpu_fan':
        return (
          'Thermal paste + Phillips #2',
          'Cooler screws/push-pins in cross pattern',
          'Paste coverage is appropriate, cooler pressure is even, every fastener is locked, and CPU_FAN is connected.',
        );
      case 'ram':
        return (
          'Hands + DIMM latches',
          'Both slot retaining clips',
          'The DDR4 notch aligns, the module is evenly seated, both latches clamp fully, and no gold contacts remain exposed.',
        );
      case 'ram_ddr5_distractor':
        return (
          'Compatibility chart',
          'Do not force incompatible memory',
          'DDR generation, notch position, voltage, and motherboard support are confirmed before insertion.',
        );
      case 'gpu':
        return (
          'Phillips #2 + ESD strap',
          'PCIe retention latch + bracket screws',
          'The card is fully seated in PCIe x16, the latch is engaged, and the bracket is secured without chassis strain.',
        );
      case 'ssd':
        return (
          'Phillips #1 screwdriver',
          'M3 SSD screws',
          'The drive is level, secured with the correct short screws, and its connectors remain accessible.',
        );
      case 'psu':
        return (
          'Phillips #2 screwdriver',
          'Four 6-32 PSU chassis screws',
          'The PSU fan faces ventilation, all four rear screws are snug, and no cable is pinched.',
        );
      case 'assembly_test':
        return (
          'POST checklist + flashlight',
          'Final fastener and clearance inspection',
          'No loose screws remain; fans spin freely; POST completes; CPU, RAM, GPU, and storage are detected.',
        );
    }
    if (item.category == 'cable') {
      return (
        'Connector key + latch inspection',
        'Keyed plug fully seated; never forced',
        'Pin count, key shape, label, latch, polarity, routing, and strain relief all match the destination.',
      );
    }
    if (item.category == 'identification') {
      return (
        'ESD-safe magnifier',
        'Handle only by edges',
        'Classification is supported by observable form factor, contacts, sockets, ports, and component markings.',
      );
    }
    if (item.category == 'network') {
      return (
        'Network diagram + cable tester',
        'Correct port, address, or topology role',
        'Physical link, addressing, gateway, service reachability, and documentation are verified.',
      );
    }
    if (item.category == 'diagnostic') {
      return (
        'Diagnostic toolkit + service checklist',
        'Use approved test instrument/procedure',
        'Evidence is recorded, one variable is changed at a time, the repair is retested, and the result is documented.',
      );
    }
    return (
      'Manufacturer manual + job checklist',
      'Follow the approved procedure and controls',
      'The action meets client requirements, OHS guidance, manufacturer instructions, testing, and documentation requirements.',
    );
  }

  String _compatibilityFeedback(sim_models.DraggableItem item, String slotId) {
    if (item.id.contains('ddr5') && slotId == 'ram_slot') {
      return 'DDR5 cannot be installed in this DDR4 slot. Both use 288 pins, but the notch position, voltage, and electrical layout differ.';
    }
    if (item.id == 'gpu_power' && slotId == 'cpu_power_slot') {
      return 'A PCIe 6+2 plug is wired for a GPU. The CPU header requires an EPS12V 4+4 plug; forcing it can damage the board.';
    }
    if (item.id == 'cpu_power' && slotId == 'gpu_power_slot') {
      return 'This EPS12V 4+4 connector powers the CPU, not the GPU. Check the key shapes and cable label.';
    }
    if (item.id == 'sata_power_distractor' && slotId == 'sata_slot') {
      return 'This is the wider 15-pin SATA power plug. The motherboard port accepts the narrower 7-pin SATA data connector.';
    }
    if (item.id == 'power_cable') {
      return 'The 24-pin ATX connector only fits the motherboard main-power header. Match the long keyed socket and locking tab.';
    }
    if (widget.simulation.id == 'sim_coc2_crimping') {
      return '${item.name} does not match ${_slotName(slotId)} in the T568B color sequence.';
    }
    if (widget.simulation.id == 'sim_coc2_ipconfig') {
      return '${item.name} is assigned to another device. Check the host address and avoid duplicate IP assignments.';
    }
    if (widget.simulation.type == 'procedure') {
      return 'This action is out of sequence for ${_slotName(slotId)}. Follow the technical workflow one stage at a time.';
    }
    return '${item.name} does not match ${_slotName(slotId)}. ${item.tooltip}';
  }

  String _slotName(String slotId) {
    const names = <String, String>{
      'motherboard_tray': 'the motherboard tray',
      'cpu_socket': 'the CPU socket',
      'cpu_fan_mount': 'the cooler mount',
      'ram_slot': 'the DDR4 memory slot',
      'pcie_slot': 'the PCIe x16 slot',
      'storage_bay': 'the storage bay',
      'psu_mount': 'the PSU mount',
      'power_slot': 'the 24-pin ATX header',
      'cpu_power_slot': 'the 8-pin EPS12V CPU header',
      'gpu_power_slot': 'the GPU PCIe power socket',
      'sata_slot': 'the 7-pin SATA data port',
      'front_panel_slot': 'the front-panel header',
    };
    if (slotId.startsWith('pin')) {
      return 'RJ45 ${slotId.replaceFirst('pin', 'pin ')}';
    }
    return names[slotId] ?? slotId.replaceAll('_', ' ');
  }

  int get _nextAssemblyStep => _placements.length + 1;

  List<sim_models.DraggableItem> get _requiredItems =>
      widget.simulation.items.where((item) => item.isRequired).toList();

  sim_models.DraggableItem? _itemForStep(int step) {
    for (final item in widget.simulation.items) {
      if (item.step == step) {
        return item;
      }
    }

    return null;
  }

  void _calculateScore() {
    var correct = 0;
    final total = _requiredItems.length;

    for (final item in _requiredItems) {
      if (_placements[item.id] == item.correctSlot) {
        correct++;
      }
    }

    final scoredCorrect = (correct - (widget.practice ? 0 : _mistakes)).clamp(
      0,
      total,
    );
    final percentage = total == 0 ? 0 : (scoredCorrect / total * 100).round();
    final passed = percentage >= widget.simulation.passingScore;

    setState(() {
      _isComplete = true;
    });
    _missionTimer?.cancel();

    if (passed) {
      SystemSound.play(SystemSoundType.click);
      _speak(
        'Mission complete. Excellent work. You earned $_xp experience points.',
      );
    } else {
      SystemSound.play(SystemSoundType.alert);
      _speak('Mission incomplete. Review the hints and try again.');
    }
    _showResultDialog(percentage, passed, scoredCorrect, total);

    widget.onFeedback?.call(List.unmodifiable(_errorLog));
    widget.onComplete(scoredCorrect, total, passed);
  }

  void _showResultDialog(int percentage, bool passed, int correct, int total) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.refresh,
                color: passed ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(passed ? 'Excellent!' : 'Keep Practicing!'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passed
                      ? 'Mission cleared with $_xp XP and $_mistakes mistakes.'
                      : 'Mission score: $correct of $total. Mistakes: $_mistakes.',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: passed
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: passed
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        passed ? Icons.thumb_up : Icons.emoji_events,
                        color: passed ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Score: $percentage% '
                          '(${widget.simulation.passingScore}% needed to pass)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: passed
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorLog.isNotEmpty || !passed) ...[
                  const SizedBox(height: 8),
                  Text(
                    _incorrectFeedback,
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                ],
                if (widget.simulation.id.contains('crimp'))
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Real-world RJ45 fault guide (possible causes, not a physical diagnosis):\n'
                      '• Open circuit: conductor not fully seated or cut short; reterminate and test continuity.\n'
                      '• Short: conductors touch or a damaged plug; inspect and replace the termination.\n'
                      '• Reversed/miswired pair: incorrect pin order; verify both ends against the selected T568B standard.\n'
                      '• Split pair: continuity can pass but signal quality fails; preserve twisted-pair assignments and test with a capable tester.\n'
                      '• Link light on but no connectivity: also check IP address, subnet, gateway and VLAN; crimping alone does not prove network configuration.',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            SummaryPrintButton(
              title: 'Simulation - ' + widget.simulation.title,
              load: () async => [
                SummarySection(
                  'Session result',
                  ['Score', 'Total', 'Percentage', 'Outcome', 'Mistakes'],
                  [
                    [
                      correct,
                      total,
                      percentage,
                      passed ? 'Passed' : 'Needs practice',
                      _mistakes,
                    ],
                  ],
                ),
                SummarySection(
                  'Feedback',
                  ['Observation'],
                  [
                    for (final error in _errorLog) [error],
                  ],
                ),
              ],
            ),
            if (passed)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Continue'),
              ),
            if (!passed)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _resetSimulation();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Retry'),
              ),
          ],
        );
      },
    );
  }

  String get _incorrectFeedback {
    final incorrect = _requiredItems.where(
      (item) => _placements[item.id] != item.correctSlot,
    );
    return [
      'Review these errors before retrying:',
      ..._errorLog,
      for (final item in incorrect)
        '- ${item.name}: ${item.tooltip.isEmpty ? 'Check the correct target and sequence.' : item.tooltip}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < MediaQuery.sizeOf(context).height) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.screen_rotation_rounded,
                size: 48,
                color: Color(0xFF2563EB),
              ),
              SizedBox(height: 16),
              Text(
                'Turn your screen sideways',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'The landscape workbench gives your parts and targets room to breathe.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (widget.simulation.id == 'sim_coc1_assembly' && !_preflightComplete) {
      return LayoutBuilder(
        builder: (context, size) =>
            size.maxHeight < 580 ? _compactReadiness(true) : _buildPreflight(),
      );
    }
    if (widget.simulation.id == 'sim_coc1_os_install' &&
        !_osPreflightComplete) {
      return LayoutBuilder(
        builder: (context, size) => size.maxHeight < 580
            ? _compactReadiness(false)
            : _buildOsPreflight(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 560.0;
        final trayWidth = (constraints.maxWidth * .27).clamp(180.0, 260.0);
        return SizedBox(
          height: height,
          child: Column(
            children: [
              _buildStatusBar(),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, space) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: trayWidth,
                        child: _buildPartsPanel(space.maxHeight),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildWorkbench(space.maxHeight)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _trayPage = 0;
  int _readinessIndex = 0;

  Widget _compactReadiness(bool assembly) {
    final checks = assembly
        ? const [
            (
              'Disconnect power',
              'Switch off the PSU and remove its power cable.',
            ),
            ('Use ESD protection', 'Wear a grounded anti-static wrist strap.'),
            ('Prepare the bench', 'Clear screws, tools and packaging.'),
          ]
        : const [
            (
              'Verify backup',
              'Confirm required files open from the backup destination.',
            ),
            (
              'Verify installer',
              'Confirm the approved ISO checksum and bootable USB.',
            ),
            (
              'Check deployment',
              'Verify hardware, license, network and stable power.',
            ),
          ];
    final selected = assembly ? _safetyChecks : _osReadinessChecks;
    final index = _readinessIndex.clamp(0, checks.length - 1);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Safety check ${index + 1} of ${checks.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              value: selected.contains(index),
              title: Text(checks[index].$1),
              subtitle: Text(checks[index].$2),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  selected.add(index);
                } else {
                  selected.remove(index);
                }
              }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: index == 0
                      ? null
                      : () => setState(() => _readinessIndex--),
                  child: const Text('Previous'),
                ),
                FilledButton(
                  onPressed: !selected.contains(index)
                      ? null
                      : () {
                          if (index < checks.length - 1) {
                            setState(() => _readinessIndex++);
                          } else if (assembly) {
                            _beginAssembly();
                          } else {
                            _beginOsInstallation();
                          }
                        },
                  child: Text(index < checks.length - 1 ? 'Next' : 'Start'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _inspectItem(sim_models.DraggableItem item) {
    setState(() => _focusedItemId = item.id);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Text(
            '${item.tooltip}\n\n${item.specification}\n\nResource: ${_resourceProfile(item).$1}\nControl: ${_resourceProfile(item).$2}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConfidence() => showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Identification confidence'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Higher confidence earns more XP, but a wrong classification costs more.',
            ),
            for (var value = 1; value <= 3; value++)
              ListTile(
                leading: Icon(
                  _identificationConfidence == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(['Low', 'Medium', 'High'][value - 1]),
                onTap: () {
                  setState(() => _identificationConfidence = value);
                  update(() {});
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );

  Widget _buildPreflight() {
    const checks = [
      (
        Icons.power_off_rounded,
        'Disconnect power',
        'PSU switch off and cable removed',
      ),
      (
        Icons.health_and_safety_outlined,
        'Use ESD protection',
        'Wear a grounded anti-static strap',
      ),
      (
        Icons.handyman_outlined,
        'Prepare the bench',
        'Clear screws, tools, and packaging',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101A24),
        borderRadius: BorderRadius.circular(18),
        image: const DecorationImage(
          image: AssetImage(
            'assets/simulations/pc-case-workbench-realistic.png',
          ),
          fit: BoxFit.cover,
          opacity: .22,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 38),
          const SizedBox(height: 12),
          const Text(
            'WORKSHOP PRE-FLIGHT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'A real technician makes the workstation safe before touching hardware.',
            style: TextStyle(color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < checks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: _safetyChecks.contains(i),
                onChanged: (value) => setState(
                  () => value == true
                      ? _safetyChecks.add(i)
                      : _safetyChecks.remove(i),
                ),
                secondary: Icon(checks[i].$1, color: Colors.white),
                title: Text(
                  checks[i].$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  checks[i].$3,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
                activeColor: const Color(0xFF0EA5E9),
                checkColor: Colors.white,
                tileColor: Colors.black38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _safetyChecks.length == checks.length
                  ? _beginAssembly
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _safetyChecks.length == checks.length
                    ? 'Enter assembly bay'
                    : 'Complete all safety checks',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOsPreflight() {
    const checks = [
      (
        Icons.backup_outlined,
        'Backup verified',
        'Required user files open correctly from the backup destination',
      ),
      (
        Icons.usb_rounded,
        'Installer verified',
        'Approved ISO checksum and bootable USB have been confirmed',
      ),
      (
        Icons.power_outlined,
        'Deployment ready',
        'Hardware requirements, license, network, and stable power are ready',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071A33), Color(0xFF123E70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFF7DD3FC),
                size: 32,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEPLOYMENT READINESS GATE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    Text(
                      'A clean installation can erase data. Confirm every control before continuing.',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < checks.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: CheckboxListTile(
                value: _osReadinessChecks.contains(index),
                onChanged: (checked) => setState(
                  () => checked == true
                      ? _osReadinessChecks.add(index)
                      : _osReadinessChecks.remove(index),
                ),
                secondary: Icon(checks[index].$1, color: Colors.white),
                title: Text(
                  checks[index].$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  checks[index].$3,
                  style: const TextStyle(
                    color: Color(0xFFB6C8DA),
                    fontSize: 11,
                  ),
                ),
                activeColor: const Color(0xFF0284C7),
                checkColor: Colors.white,
                tileColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _osReadinessChecks.length == checks.length
                  ? _beginOsInstallation
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _osReadinessChecks.length == checks.length
                    ? 'Start controlled installation'
                    : 'Complete all readiness checks',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkbenchGuide() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Using the workbench'),
      scrollable: true,
      content: Text(
        '1. Choose the correct tool or resource in the parts tray.\n\n'
        '2. Drag a part onto its matching target on the workbench.\n\n'
        '3. Tap a part to inspect its specifications and technical guidance.\n\n'
        'Use the tray arrows to see more parts. Pinch the workbench or use Zoom to inspect small targets.\n\n'
        'Passing score: ${widget.simulation.passingScore}%.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Widget _buildStatusBar() => Container(
    height: 40,
    padding: const EdgeInsets.only(left: 12, right: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0F7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.task_alt_rounded, size: 18, color: Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_placements.length}/${_requiredItems.length} placed  ·  $_mistakes errors  ·  $_formattedElapsed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334E68),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Guided process',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                SimulationProcessGuide(simulation: widget.simulation),
          ),
          icon: const Icon(Icons.play_circle_outline, size: 20),
        ),
        IconButton(
          tooltip: 'Workbench guide',
          onPressed: _showWorkbenchGuide,
          icon: const Icon(Icons.help_outline_rounded, size: 20),
        ),
        if (widget.simulation.type == 'identification')
          IconButton(
            tooltip: 'Identification confidence',
            onPressed: _showConfidence,
            icon: const Icon(Icons.psychology_outlined, size: 20),
          ),
        IconButton(
          tooltip: _cableZoom > 1 ? 'Reset view' : 'Zoom in',
          onPressed: () => _setCableZoom(_cableZoom > 1 ? 1 : 1.8),
          icon: Icon(
            _cableZoom > 1 ? Icons.center_focus_strong : Icons.zoom_in_rounded,
            size: 20,
          ),
        ),
        IconButton(
          tooltip: _voiceEnabled
              ? 'Mute voice guidance'
              : 'Enable voice guidance',
          onPressed: () {
            setState(() => _voiceEnabled = !_voiceEnabled);
            if (!_voiceEnabled) _tts.stop();
          },
          icon: Icon(
            _voiceEnabled
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            size: 20,
          ),
        ),
        IconButton(
          tooltip: 'Reset activity',
          onPressed: _resetSimulation,
          icon: const Icon(Icons.restart_alt_rounded, size: 20),
        ),
      ],
    ),
  );

  String get _formattedElapsed {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildPartsPanel(double panelHeight) {
    final resources = widget.simulation.items
        .map((item) => _resourceProfile(item).$1)
        .toSet()
        .toList();
    final perPage = max(1, ((panelHeight - 104) / 48).floor());
    final pages = max(1, (_availableItems.length / perPage).ceil());
    final page = _trayPage.clamp(0, pages - 1);
    final visible = _availableItems.skip(page * perPage).take(perPage).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE5EF)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Parts  ${page + 1}/$pages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous parts',
                  onPressed: page > 0
                      ? () => setState(() => _trayPage = page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 20),
                ),
                IconButton(
                  tooltip: 'Next parts',
                  onPressed: page + 1 < pages
                      ? () => setState(() => _trayPage = page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 20),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: DropdownButtonFormField<String>(
              key: ValueKey(_selectedResource),
              initialValue: _selectedResource,
              itemHeight: null,
              selectedItemBuilder: (context) => resources
                  .map(
                    (r) => Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: r,
                        child: Text(
                          r,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select tool',
                hintStyle: TextStyle(fontSize: 11),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              items: resources
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedResource = value),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _availableItems.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.task_alt_rounded,
                      color: Color(0xFF059669),
                      size: 32,
                    ),
                  )
                : Column(
                    children: [
                      for (final id in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: DraggableItemWidget(
                            item: widget.simulation.items.firstWhere(
                              (item) => item.id == id,
                            ),
                            isComplete: _isComplete,
                            compact: true,
                            labelOnly:
                                widget.simulation.type == 'identification' ||
                                widget.simulation.id == 'sim_coc1_os_install',
                            isFocused: _focusedItemId == id,
                            onInspect: () => _inspectItem(
                              widget.simulation.items.firstWhere(
                                (item) => item.id == id,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkbench(double activityHeight) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = activityHeight;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFF17283B),
          child: InteractiveViewer(
            transformationController: _cableZoomController,
            minScale: 1,
            maxScale: 3.5,
            onInteractionUpdate: (_) {
              final zoom = _cableZoomController.value.getMaxScaleOnAxis();
              if ((zoom - _cableZoom).abs() > .02) {
                setState(() => _cableZoom = zoom);
              }
            },
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(child: _buildWorkbenchBackground()),
                  ...widget.simulation.slots.where(_shouldDisplaySlot).map((
                    slot,
                  ) {
                    final size = _targetSize(slot, width, height);
                    final position = _targetPosition(slot, width, height, size);
                    return Positioned(
                      left: position.dx,
                      top: position.dy,
                      child: DropTargetWidget(
                        slotId: slot,
                        placedItem: _placedItemFor(slot),
                        isComplete: _isComplete,
                        onDrop: _handleDrop,
                        canAccept: (id) =>
                            widget.simulation.items
                                .firstWhere((item) => item.id == id)
                                .correctSlot ==
                            slot,
                        specimenItem: widget.simulation.type == 'identification'
                            ? widget.simulation.items.firstWhere(
                                (item) => item.correctSlot == slot,
                              )
                            : null,
                        onInspectSpecimen:
                            widget.simulation.type == 'identification'
                            ? () => _showSpecimenInspection(slot)
                            : null,
                        workflowMode:
                            widget.simulation.id == 'sim_coc1_os_install',
                        width: size.width,
                        height: size.height,
                        compact: size.height < 110,
                        immersive:
                            widget.simulation.id == 'sim_coc1_assembly' ||
                            widget.simulation.id == 'sim_coc1_cabling' ||
                            widget.simulation.competency == 'COC2',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  void _showSpecimenInspection(String slotId) {
    final specimen = widget.simulation.items.firstWhere(
      (item) => item.correctSlot == slotId,
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inspect specimen'),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.asset(specimen.imageUrl, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              Text(specimen.tooltip),
              if (specimen.specification.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(specimen.specification),
              ],
              const SizedBox(height: 8),
              const Text(
                'Inspect the evidence, choose your confidence, then drag the matching label onto the specimen.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _setCableZoom(double value) {
    final zoom = value.clamp(1.0, 3.5);
    setState(() => _cableZoom = zoom);
    _cableZoomController.value = Matrix4.diagonal3Values(zoom, zoom, 1);
  }

  sim_models.DraggableItem? _placedItemFor(String slotId) {
    for (final entry in _placements.entries) {
      if (entry.value == slotId) {
        for (final item in widget.simulation.items) {
          if (item.id == entry.key) {
            return item;
          }
        }
      }
    }

    return null;
  }

  bool _shouldDisplaySlot(String slotId) {
    if (!_requiredItems.any((item) => item.correctSlot == slotId)) return false;
    if (widget.simulation.id != 'sim_coc1_assembly') return true;

    switch (slotId) {
      case 'cpu_socket':
        return _placements.containsKey('motherboard') ||
            _placements.containsKey('cpu');
      case 'cpu_fan_mount':
        return _placements.containsKey('cpu') ||
            _placements.containsKey('cpu_fan');
      default:
        return true;
    }
  }

  bool get _gridTargets => !const {
    'sim_coc1_assembly',
    'sim_coc1_cabling',
    'sim_coc1_identification',
  }.contains(widget.simulation.id);

  Size _targetSize(String slotId, double benchWidth, double benchHeight) {
    if (_gridTargets) {
      final columns = widget.simulation.id == 'sim_coc2_crimping' ? 4 : 3;
      final count = widget.simulation.slots.where(_shouldDisplaySlot).length;
      final rows = max(1, (count / columns).ceil());
      return Size(
        (benchWidth - 24 - (columns - 1) * 8) / columns,
        (benchHeight - 24 - (rows - 1) * 8) / rows,
      );
    }
    switch (slotId) {
      case 'assembly_test_station':
      case 'cable_test_station':
        return Size(benchWidth * .24, benchHeight * .16);
      case 'motherboard_tray':
        // The matched ATX board is rendered in the same upright, top-down
        // orientation as the case. Keep its real proportions so the CPU,
        // DIMM and PCIe layers land over the sockets drawn on the board.
        return Size((benchWidth * .36).clamp(150.0, 310.0), benchHeight * .58);
      case 'cpu_target':
      case 'ram_target':
      case 'gpu_target':
      case 'motherboard_target':
      case 'storage_target':
      case 'psu_target':
        return Size(benchWidth * .27, benchHeight * .34);
      case 'pcie_slot':
        return Size((benchWidth * .38).clamp(120.0, 260.0), benchHeight * .13);
      case 'psu_mount':
        return Size((benchWidth * .25).clamp(95.0, 180.0), benchHeight * .18);
      case 'ram_slot':
        return Size((benchWidth * .07).clamp(38.0, 58.0), benchHeight * .30);
      case 'cpu_socket':
        return Size.square((benchHeight * .13).clamp(48.0, 68.0));
      case 'cpu_fan_mount':
        return Size.square((benchHeight * .21).clamp(70.0, 108.0));
      case 'storage_bay':
        return Size(benchWidth * .13, benchHeight * .14);
      case 'power_slot':
        return Size(benchWidth * .22, benchHeight * .18);
      case 'cpu_power_slot':
        return Size(benchWidth * .18, benchHeight * .15);
      case 'gpu_power_slot':
        return Size(benchWidth * .22, benchHeight * .17);
      case 'sata_slot':
        return Size(benchWidth * .24, benchHeight * .18);
      case 'front_panel_slot':
        return Size(benchWidth * .22, benchHeight * .18);
      default:
        return Size((benchWidth * .22).clamp(80.0, 120.0), 82);
    }
  }

  Offset _targetPosition(
    String slotId,
    double width,
    double height,
    Size targetSize,
  ) {
    if (_gridTargets) {
      final columns = widget.simulation.id == 'sim_coc2_crimping' ? 4 : 3;
      final index = widget.simulation.slots
          .where(_shouldDisplaySlot)
          .toList()
          .indexOf(slotId);
      return Offset(
        12 + (index % columns) * (targetSize.width + 8),
        12 + (index ~/ columns) * (targetSize.height + 8),
      );
    }
    final positions = <String, Offset>{
      'assembly_test_station': Offset(width * .70, height * .78),
      'cable_test_station': Offset(width * .04, height * .77),
      'motherboard_tray': Offset(width * 0.22, height * 0.16),
      'cpu_socket': Offset(width * 0.35, height * 0.30),
      'cpu_fan_mount': Offset(width * 0.33, height * 0.26),
      'ram_slot': Offset(width * 0.53, height * 0.20),
      'pcie_slot': Offset(width * 0.24, height * 0.58),
      'storage_bay': Offset(width * 0.72, height * 0.50),
      'psu_mount': Offset(width * 0.13, height * 0.76),
      'power_slot': Offset(width * 0.60, height * 0.20),
      'cpu_power_slot': Offset(width * 0.25, height * 0.11),
      'gpu_power_slot': Offset(width * 0.30, height * 0.43),
      'sata_slot': Offset(width * 0.64, height * 0.61),
      'front_panel_slot': Offset(width * 0.34, height * 0.72),
      'cpu_target': Offset(width * .05, height * .17),
      'ram_target': Offset(width * .365, height * .17),
      'gpu_target': Offset(width * .68, height * .17),
      'motherboard_target': Offset(width * .05, height * .56),
      'storage_target': Offset(width * .365, height * .56),
      'psu_target': Offset(width * .68, height * .56),
    };

    final raw = positions[slotId] ?? _genericPosition(slotId, width, height);
    return _safeTargetPosition(raw, width, height, targetSize);
  }

  Offset _safeTargetPosition(
    Offset raw,
    double width,
    double height,
    Size targetSize,
  ) {
    double safeAxis(double value, double extent, double childExtent) {
      final available = extent - childExtent;
      if (available <= 0) return 0;
      if (available < 8) return available / 2;
      return value.clamp(4.0, available - 4.0).toDouble();
    }

    return Offset(
      safeAxis(raw.dx, width, targetSize.width),
      safeAxis(raw.dy, height, targetSize.height),
    );
  }

  Offset _genericPosition(String slotId, double width, double height) {
    final index = widget.simulation.slots.indexOf(slotId);
    final columns = width < 520 ? 2 : 3;
    final cellWidth = (width - 28) / columns;

    return Offset(
      14 + (index % columns) * cellWidth,
      58 + (index ~/ columns) * 112.0,
    );
  }

  Widget _buildWorkbenchBackground() {
    if (widget.simulation.type == 'identification') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07111F), Color(0xFF0F2740), Color(0xFF07111F)],
          ),
        ),
        child: CustomPaint(painter: _EvidenceGridPainter()),
      );
    }
    final asset = _workbenchImage;
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        fit: BoxFit.cover,
        colorFilter: const ColorFilter.mode(
          Color(0x18000000),
          BlendMode.darken,
        ),
        placeholderBuilder: (_) => Container(color: const Color(0xFF26323A)),
      );
    }
    return Image.asset(
      asset,
      fit: BoxFit.fill,
      color: Colors.black.withValues(alpha: 0.10),
      colorBlendMode: BlendMode.darken,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFF26323A)),
    );
  }

  String get _workbenchImage {
    switch (widget.simulation.id) {
      case 'sim_coc1_assembly':
        return 'assets/simulations/pc-case-workbench-realistic.png';
      case 'sim_coc1_cabling':
        return 'assets/simulations/cable-management-workbench.png';
      case 'sim_coc1_identification':
        return 'assets/simulations/lab-kit.svg';
      case 'sim_coc1_os_install':
        return 'assets/simulations/os-install-workbench-matched.png';
      case 'sim_coc1_software_config':
        return 'assets/simulations/software-config-workbench-matched.png';
      case 'sim_coc1_maintenance':
        return 'assets/simulations/maintenance-workbench-matched.png';
      case 'sim_coc1_repair':
        return 'assets/simulations/troubleshooting-workbench-matched.png';
      case 'sim_coc2_topology':
      case 'sim_coc2_diagnostics':
        return 'assets/simulations/coc2-network-lab-matched.png';
      case 'sim_coc2_ipconfig':
        return 'assets/simulations/ip-configuration-workbench-matched.png';
      case 'sim_coc2_crimping':
        return 'assets/simulations/coc2-rj45-workbench-matched.png';
      default:
        return 'assets/simulations/whiteboard.svg';
    }
  }
}

class _EvidenceGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fine = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: .07)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fine);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fine);
    }
    final crosshair = Paint()
      ..color = const Color(0xFF7DD3FC).withValues(alpha: .16)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width / 2 - 22, size.height / 2),
      Offset(size.width / 2 + 22, size.height / 2),
      crosshair,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2 - 22),
      Offset(size.width / 2, size.height / 2 + 22),
      crosshair,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
