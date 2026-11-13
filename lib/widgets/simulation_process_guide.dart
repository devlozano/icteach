import 'simulation_description.dart';
import 'package:flutter/material.dart' hide Simulation;
import '../data/simulation_step_detail.dart';
import '../models/simulation_model.dart';
import 'simulation_step_lab.dart';
import 'guided_setup_workbench.dart';
import '../data/guided_setup_data.dart';

/// Replayable reference; reviewed checkpoints never award assessment credit.
class SimulationProcessGuide extends StatefulWidget {
  final Simulation simulation;
  final bool embedded;
  final VoidCallback? onClose;
  const SimulationProcessGuide({
    super.key,
    required this.simulation,
    this.embedded = false,
    this.onClose,
  });
  @override
  State<SimulationProcessGuide> createState() => _SimulationProcessGuideState();
}

class _SimulationProcessGuideState extends State<SimulationProcessGuide> {
  int step = 0, replay = 0;
  final Set<int> checked = {};
  final ScrollController _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _navigate(int target) {
    setState(() => step = target);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = GuidedSetupData.kindForId(widget.simulation.id);
    if (kind != null) {
      final content = Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Guided practice • no assessment credit'),
                ),
              ),
              IconButton(
                tooltip: 'Close walkthrough',
                onPressed: _close,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: GuidedSetupWorkbench(kind: kind, onComplete: (_, _, _) {}),
          ),
        ],
      );
      if (widget.embedded) return content;
      return Dialog(insetPadding: const EdgeInsets.all(12), child: content);
    }
    final tasks =
        widget.simulation.items.where((item) => item.isRequired).toList()
          ..sort((a, b) => a.step.compareTo(b.step));
    if (tasks.isEmpty) {
      return const AlertDialog(
        title: Text('Guided process'),
        content: Text('This activity has no required steps.'),
      );
    }
    final item = tasks[step.clamp(0, tasks.length - 1)];
    final detail = SimulationStepDetail.forItem(widget.simulation, item);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Guided process',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Close walkthrough',
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              widget.simulation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Practice walkthrough • Checkpoints do not change your assessment score.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: checked.length / tasks.length),
            Expanded(
              child: ListView(
                controller: _scroll,
                children: [
                  Text(
                    'Step ${step + 1} of ${tasks.length}: ${item.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('$step-$replay'),
                    tween: Tween(
                      begin: 0,
                      end: detail.actions.length.toDouble(),
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : Duration(milliseconds: 5000 * detail.actions.length),
                    builder: (_, value, _) {
                      final action = value.floor().clamp(
                        0,
                        detail.actions.length - 1,
                      );
                      final motion = value >= detail.actions.length
                          ? 1.0
                          : value - value.floor();
                      return Column(
                        children: [
                          SimulationOperationScene(
                            simulation: widget.simulation,
                            item: item,
                            motion: AlwaysStoppedAnimation(motion),
                            action: action,
                            total: detail.actions.length,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Demonstration ${action + 1}/${detail.actions.length}: ${detail.actions[action]}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => replay++),
                      icon: const Icon(Icons.replay),
                      label: const Text('Replay demonstration'),
                    ),
                  ),
                  _section(
                    'Identify and inspect',
                    '${item.description}\n${item.specification}',
                  ),
                  for (var i = 0; i < detail.actions.length; i++)
                    _section('Operation ${i + 1}', detail.actions[i]),
                  _section('Verify before continuing', detail.expected),
                  _section(
                    'If the check fails',
                    '${detail.fault} Stop, correct the cause, repeat the operation, and inspect again.',
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
                  onPressed: step == 0 ? null : () => _navigate(step - 1),
                  child: const Text('Previous'),
                ),
                Expanded(
                  child: Text(
                    '${checked.length}/${tasks.length} reviewed',
                    textAlign: TextAlign.center,
                  ),
                ),
                Flexible(
                  child: FilledButton(
                    onPressed: !checked.contains(step)
                        ? null
                        : () {
                            if (step < tasks.length - 1) {
                              _navigate(step + 1);
                            } else {
                              _close();
                            }
                          },
                    child: Text(
                      step == tasks.length - 1
                          ? 'Return to activity'
                          : 'Next step',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFF8FAFC), child: content);
    }
    return Dialog(insetPadding: const EdgeInsets.all(12), child: content);
  }

  Widget _section(String title, String text) =>
      SimulationDescriptionSection(title: title, text: text);
}
