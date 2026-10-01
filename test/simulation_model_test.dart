import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';

void main() {
  test('simulation data contains valid scenarios', () {
    final simulations = SimulationData.getAllSimulations();
    expect(simulations, isNotEmpty);

    final simulation = simulations.first;
    expect(simulation.title, isNotEmpty);
    expect(simulation.items, isNotEmpty);
    expect(simulation.slots, hasLength(simulation.items.length));
  });

  test('every simulation item references an existing asset', () {
    final missingAssets = <String>[];

    for (final simulation in SimulationData.getAllSimulations()) {
      for (final item in simulation.items) {
        if (!File(item.imageUrl).existsSync()) {
          missingAssets.add('${simulation.id}: ${item.imageUrl}');
        }
      }
    }

    expect(
      missingAssets,
      isEmpty,
      reason: 'Missing simulation assets:\n${missingAssets.join('\n')}',
    );
  });

  test('PC disassembly is ordered, graded, and follows PC assembly', () {
    final simulation = SimulationData.getPcDisassembly();
    expect(simulation.id, 'sim_coc1_disassembly');
    expect(simulation.type, 'disassembly');
    expect(simulation.requiredSimulationId, 'sim_coc1_assembly');
    expect(simulation.passingScore, 80);
    expect(simulation.items.length, 9);
    expect(
      simulation.items.map((item) => item.step),
      orderedEquals(List<int>.generate(9, (index) => index + 1)),
    );
    expect(simulation.items.first.id, 'disassembly_safety');
    expect(simulation.items.last.id, 'disassembly_inventory');
  });
}
