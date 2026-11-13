import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/data/guided_setup_data.dart';
import 'package:icteach/widgets/guided_setup_workbench.dart';
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(body: SimulationProcessGuide(simulation: simulation)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (GuidedSetupData.kindForId(simulation.id) != null) {
        expect(find.byType(GuidedSetupWorkbench), findsOneWidget);
        expect(
          find.text('Guided practice • no assessment credit'),
          findsOneWidget,
        );
        return;
      }
      await tester.scrollUntilVisible(find.text('Replay demonstration'), 80);
      expect(find.text('Replay demonstration'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(find.byType(CheckboxListTile), 100);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byType(CheckboxListTile)),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
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

  testWidgets('embedded procedure stays inside the workbench', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SimulationProcessGuide(
            simulation: SimulationData.getPcAssembly(),
            embedded: true,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.byTooltip('Close walkthrough'));
    expect(closed, isTrue);
  });
}
