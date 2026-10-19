import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/data/simulation_step_detail.dart';
import 'package:icteach/widgets/simulation_step_lab.dart';

void main() {
  test(
    'catalog retires duplicate identification without breaking historical links',
    () {
      final catalog = SimulationData.getAllSimulations();
      final ids = catalog.map((s) => s.id).toSet();
      expect(ids.length, catalog.length);
      expect(ids, hasLength(11));
      expect(ids, isNot(contains('sim_coc1_identification')));
      expect(
        SimulationData.getSimulationById('sim_coc1_identification'),
        isNotNull,
      );
      for (final simulation in catalog) {
        if (simulation.requiredSimulationId != null) {
          expect(ids, contains(simulation.requiredSimulationId));
        }
        for (final item in simulation.items.where((i) => i.isRequired)) {
          final detail = SimulationStepDetail.forItem(simulation, item);
          expect(
            detail.actions.length,
            greaterThanOrEqualTo(4),
            reason: item.id,
          );
          expect(detail.expected, isNot(detail.fault));
          expect(detail.actions.toSet().length, detail.actions.length);
        }
      }
    },
  );

  for (final size in [
    const Size(360, 640),
    const Size(640, 320),
    const Size(1280, 800),
  ]) {
    for (final simulation in SimulationData.getAllSimulations()) {
      testWidgets(
        '${simulation.id} operation fits $size and can be cancelled',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => SimulationStepLab(
                        simulation: simulation,
                        item: simulation.items.first,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('perform-operation')),
            100,
          );
          await tester.tap(find.byKey(const ValueKey('perform-operation')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('perform-operation')),
                )
                .onPressed,
            isNull,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Cancel operation'));
          await tester.pumpAndSettle();
          expect(find.byType(SimulationStepLab), findsNothing);
        },
      );
    }
  }

  testWidgets(
    'IP input is validated and faulty observations require rework before credit',
    (tester) async {
      final simulation = SimulationData.getIpConfiguration();
      final item =
          simulation.items[1]; // even step presents a faulty observation
      final errors = <String>[];
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<bool>(
                      context: context,
                      builder: (_) => SimulationStepLab(
                        simulation: simulation,
                        item: item,
                        onMistake: errors.add,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
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
      await tester.enterText(
        find.byKey(const ValueKey('ipv4-address')),
        '192.168.1.10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('ipv4-mask')),
        '255.255.0.0',
      );
      await press('perform-operation');
      expect(errors, hasLength(1));
      expect(result, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('ipv4-address')),
        '192.168.1.11',
      );
      await tester.enterText(
        find.byKey(const ValueKey('ipv4-mask')),
        '255.255.255.0',
      );
      await press('perform-operation');
      for (var i = 0; i < 3; i++) {
        await press('perform-operation');
      }
      await press('accept-operation');
      expect(errors, hasLength(2));
      expect(result, isNull);
      await press('rework-operation');
      await press('perform-operation');
      await press('accept-operation');
      expect(result, isTrue);
      expect(find.byType(SimulationStepLab), findsNothing);
    },
  );
}
