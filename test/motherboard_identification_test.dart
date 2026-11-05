import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/motherboard_parts.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/widgets/motherboard_identification.dart';

void main() {
  test('active practicals have no retired prerequisite', () {
    final catalog = SimulationData.getAllSimulations();
    final ids = catalog.map((s) => s.id).toSet();
    expect(ids, contains('sim_coc1_motherboard'));
    expect(ids, isNot(contains('sim_coc2_topology')));
    for (final simulation in catalog) {
      if (simulation.requiredSimulationId != null) {
        expect(ids, contains(simulation.requiredSimulationId));
      }
    }
  });

  testWidgets('locate parts on the board and complete only after all parts', (
    tester,
  ) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MotherboardIdentification(
            onComplete: (score, total, passed) {
              result = score;
            },
          ),
        ),
      ),
    );
    final board = find.byKey(const ValueKey('motherboard-image'));
    final bounds = tester.getRect(board);
    await tester.tapAt(bounds.topLeft + const Offset(1, 1));
    await tester.pump();
    expect(find.textContaining('try again'), findsOneWidget);
    expect(result, isNull);
    for (var i = 0; i < MotherboardParts.entries.length; i++) {
      final center = MotherboardParts.entries[i].$3.center;
      await tester.tapAt(
        bounds.topLeft +
            Offset(center.dx * bounds.width, center.dy * bounds.height),
      );
      await tester.pump();
      expect(find.text(MotherboardParts.entries[i].$4), findsOneWidget);
      await tester.tap(
        find.text(
          i == MotherboardParts.entries.length - 1
              ? 'Finish inspection'
              : 'Next part',
        ),
      );
      await tester.pump();
    }
    expect(result, MotherboardParts.entries.length - 1);
  });
}
