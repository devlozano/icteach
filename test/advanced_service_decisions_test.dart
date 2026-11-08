import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/service_decisions.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/data/simulation_step_detail.dart';
import 'package:icteach/widgets/simulation_step_lab.dart';

void main() {
  for (final slot in ServiceDecision.bySlot.keys) {
    testWidgets(
      '$slot rejects wrong actions and completes only after verification',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final simulation = SimulationData.getAllSimulations().singleWhere(
          (s) => s.items.any((i) => i.correctSlot == slot),
        );
        final item = simulation.items.singleWhere((i) => i.correctSlot == slot);
        final decision = ServiceDecision.bySlot[slot]!;
        final mistakes = <String>[];
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<bool>(
                      context: context,
                      builder: (_) => SimulationStepLab(
                        simulation: simulation,
                        item: item,
                        onMistake: mistakes.add,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        Future<void> press(String key) async {
          final target = find.byKey(ValueKey(key));
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await press('perform-operation');
        expect(mistakes, hasLength(1));
        expect(result, isNull);
        await press(
          'service-choice-${(decision.correctIndex + 1) % decision.options.length}',
        );
        await press('perform-operation');
        expect(mistakes.last, contains(decision.explanation));
        expect(
          find.text(
            'Operation 1 of ${SimulationStepDetail.forItem(simulation, item).actions.length}',
          ),
          findsOneWidget,
        );
        await press('service-choice-${decision.correctIndex}');
        final actionCount = SimulationStepDetail.forItem(
          simulation,
          item,
        ).actions.length;
        for (var action = 0; action < actionCount; action++) {
          await press('perform-operation');
        }
        expect(result, isNull);
        if (item.step.isEven) {
          await press('accept-operation');
          expect(result, isNull);
          await press('rework-operation');
          await press('perform-operation');
        }
        await press('accept-operation');
        expect(result, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
