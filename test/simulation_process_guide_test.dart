import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/data/guided_setup_data.dart';
import 'package:icteach/data/simulation_tutorials.dart';
import 'package:icteach/widgets/guided_setup_workbench.dart';
import 'package:icteach/widgets/simulation_process_guide.dart';
import 'package:icteach/widgets/rj45_procedure_demo.dart';
import 'package:icteach/widgets/pc_build_workbench.dart';
import 'package:icteach/widgets/drag_drop_simulation.dart';

void main() {
  test('every active simulation has a YouTube practice tutorial', () {
    for (final simulation in SimulationData.getAllSimulations()) {
      final tutorial = SimulationTutorials.forId(simulation.id);
      expect(tutorial, isNotNull, reason: simulation.id);
      expect(Uri.parse(tutorial!.url).host, 'www.youtube.com');
      expect(Uri.parse(tutorial.url).queryParameters['v'], isNotEmpty);
    }
  });

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
      expect(
        find.byKey(const ValueKey('practice-video-tutorial')),
        findsOneWidget,
      );
      if (simulation.id == 'sim_coc1_assembly' ||
          simulation.id == 'sim_coc1_cabling') {
        expect(find.byType(PcBuildWorkbench), findsOneWidget);
        final play = find.byKey(const ValueKey('demonstrate-build-operation'));
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            'Operation 2 / ${simulation.id == 'sim_coc1_assembly' ? 11 : 4}',
          ),
          findsOneWidget,
        );
        return;
      }
      if (GuidedSetupData.kindForId(simulation.id) != null) {
        expect(find.byType(GuidedSetupWorkbench), findsOneWidget);
        expect(
          find.text('Guided practice • no assessment credit'),
          findsOneWidget,
        );
        return;
      }
      if (simulation.id == 'sim_coc2_crimping') {
        expect(find.byType(Rj45ProcedureDemo), findsOneWidget);
        expect(
          find.byKey(const ValueKey('rj45-procedure-motion')),
          findsOneWidget,
        );
        expect(find.text('Measure and strip 30 mm of jacket'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
        return;
      }
      await tester.scrollUntilVisible(find.text('Replay demonstration'), 80);
      expect(find.text('Replay demonstration'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('guided-process-next')),
            )
            .onPressed,
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
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('guided-process-next')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('guided-process-next')));
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

  testWidgets('RJ45 procedure advances slowly through the proper workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Rj45ProcedureDemo())),
    );
    expect(find.text('Measure and strip 30 mm of jacket'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Measure and strip 30 mm of jacket'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Cut the plastic spline'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause demonstration'));
    await tester.tap(find.byTooltip('Next procedure step'));
    await tester.pump();
    expect(find.text('Untwist only the required length'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the RJ45 guide preserves the active cable session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final simulation = SimulationData.getAllSimulations().firstWhere(
      (item) => item.id == 'sim_coc2_crimping',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DragDropSimulation(
            simulation: simulation,
            practice: true,
            onComplete: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Straight-through'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('strip-length-ruler')), findsOneWidget);

    await tester.tap(find.byTooltip('Animated procedure'));
    await tester.pump();
    expect(find.byType(Rj45ProcedureDemo), findsOneWidget);
    await tester.tap(find.byTooltip('Close walkthrough'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('strip-length-ruler')), findsOneWidget);
    expect(find.text('Select a cable task'), findsNothing);
    expect(find.text('RJ45 CABLE WORKSHOP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('graded PC assembly hides guidance and walkthrough controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final simulation = SimulationData.getPcAssembly();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PcBuildWorkbench(
            items: simulation.items,
            completed: const <String>{},
            showGuidance: false,
            onMistake: (_) {},
            onCompleteStep: (_) => true,
          ),
        ),
      ),
    );
    expect(find.text('Description'), findsNothing);
    expect(find.textContaining('FIT CHECK'), findsNothing);
    expect(find.textContaining('Rotate the keyed connector'), findsNothing);
    expect(
      find.byKey(const ValueKey('demonstrate-build-operation')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
