import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/screens/student/simulation_page.dart';
import 'package:icteach/screens/teacher/learning_path_manager.dart';

void main() {
  test('student and teacher catalogs stay within COC1 and COC2', () {
    final catalog = SimulationData.getAllSimulations();
    expect(catalog, hasLength(10));
    expect(catalog.map((s) => s.competency).toSet(), {'COC1', 'COC2'});
    final ids = catalog.map((s) => s.id).toSet();
    expect(ids, isNot(contains('sim_coc1_motherboard')));
    expect(
      SimulationData.getSimulationById('sim_coc1_motherboard'),
      isNotNull,
      reason: 'Historical links remain readable after moving it to Quizzes.',
    );
    expect(
      LearningPathManager.availableSimulations().map((s) => s.id).toSet(),
      ids,
    );
    for (final id in SimulationData.retiredSimulationIds) {
      expect(ids, isNot(contains(id)));
      expect(SimulationData.getSimulationById(id), isNull);
    }
    for (final simulation in catalog) {
      if (simulation.requiredSimulationId != null) {
        expect(ids, contains(simulation.requiredSimulationId));
      }
    }
  });
  for (final id in SimulationData.retiredSimulationIds) {
    for (final bypass in [false, true]) {
      testWidgets('$id cannot reopen through an old link, bypass=$bypass', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SimulationPage(
              classId: 'historical-class',
              simulationId: id,
              title: 'Retired activity',
              testingBypass: bypass,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Simulation unavailable'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
