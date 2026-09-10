import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/widgets/simulation_process_guide.dart';

void main() {
  for (final simulation in SimulationData.getAllSimulations()) {
    testWidgets('${simulation.id} has a bounded animated walkthrough', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimulationProcessGuide(simulation: simulation)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Replay demonstration'), 80);
      expect(find.text('Replay demonstration'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(find.byType(CheckboxListTile), 100);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining('Step 2 of'), -100);
      expect(find.textContaining('Step 2 of'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
