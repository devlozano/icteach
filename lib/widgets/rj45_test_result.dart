import 'package:flutter/material.dart';

import '../models/rj45_session.dart';

class Rj45TestResult extends StatelessWidget {
  const Rj45TestResult({
    super.key,
    required this.session,
    required this.onRetry,
    required this.onSubmit,
  });

  final Rj45Session session;
  final ValueChanged<int> onRetry;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final passed = session.passed;
    final correctPins = List.generate(
      8,
      (index) => session.wireMap[index] == session.expectedMap[index],
    ).where((correct) => correct).length;
    final accent = passed ? const Color(0xff16845b) : const Color(0xffc53b3b);
    final soft = passed ? const Color(0xffe8f7f0) : const Color(0xffffeeee);

    return Container(
      key: const ValueKey('lan-test-result'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            color: soft,
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    passed ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passed ? 'LAN TEST PASSED' : 'LAN TEST FAILED',
                        style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        passed
                            ? 'All pins match the selected cable standard.'
                            : '$correctPins of 8 pins match. Re-terminate the incorrect end.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$correctPins/8',
                        style: TextStyle(
                          color: accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text('PINS', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MAIN TO REMOTE WIRE MAP',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Each tile compares the detected remote pin with the expected pin.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 520 ? 4 : 8;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 8,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: columns == 4 ? .78 : .82,
                      ),
                      itemBuilder: (_, index) => _PinResult(
                        mainPin: index + 1,
                        observedPin: session.wireMap[index],
                        expectedPin: session.expectedMap[index],
                      ),
                    );
                  },
                ),
                if (!session.standardEnds) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff7e6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffffd184)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xffa86600),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nonstandard color or pair assignment detected. Matching LEDs can still hide split pairs. Compare both plugs with T568A or T568B before re-terminating.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 10),
                  leading: const Icon(Icons.cable_rounded),
                  title: const Text('Connector color order'),
                  subtitle: const Text(
                    'Review the eight conductors on both ends',
                  ),
                  children: [
                    for (var end = 0; end < 2; end++)
                      _ConnectorOrder(
                        label: end == 0 ? 'End A' : 'End B',
                        wires: session.ends[end].pins
                            .map((wire) => Rj45Session.colors[wire!])
                            .toList(),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var end = 0; end < 2; end++)
                      OutlinedButton.icon(
                        onPressed: () => onRetry(end),
                        icon: const Icon(Icons.content_cut_rounded),
                        label: Text(end == 0 ? 'Retry plug A' : 'Retry plug B'),
                      ),
                    FilledButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.task_alt_rounded),
                      label: const Text('Submit result'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinResult extends StatelessWidget {
  const _PinResult({
    required this.mainPin,
    required this.observedPin,
    required this.expectedPin,
  });

  final int mainPin;
  final int observedPin;
  final int expectedPin;

  @override
  Widget build(BuildContext context) {
    final correct = observedPin == expectedPin;
    final color = correct ? const Color(0xff16845b) : const Color(0xffc53b3b);
    return Container(
      key: ValueKey('lan-pin-$mainPin'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$mainPin',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: color,
                ),
              ),
              Text(
                '$observedPin',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Icon(
            correct ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 17,
          ),
          Text(
            correct ? 'Correct' : 'Expected $expectedPin',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectorOrder extends StatelessWidget {
  const _ConnectorOrder({required this.label, required this.wires});

  final String label;
  final List<String> wires;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var index = 0; index < wires.length; index++)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '${index + 1}. ${wires[index]}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
