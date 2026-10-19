import 'package:flutter/material.dart' hide Simulation;
import '../data/simulation_step_detail.dart';
import '../models/simulation_model.dart';
import 'simulation_step_lab.dart';

/// Replayable reference; reviewed checkpoints never award assessment credit.
class SimulationProcessGuide extends StatefulWidget {
  final Simulation simulation;
  const SimulationProcessGuide({super.key, required this.simulation});
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

  @override
  Widget build(BuildContext context) {
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
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
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
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 1800),
                      builder: (_, value, _) => SimulationOperationScene(
                        simulation: widget.simulation,
                        item: item,
                        motion: AlwaysStoppedAnimation(value),
                        action: 0,
                        total: detail.actions.length,
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
                                Navigator.pop(context);
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
