import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/pc_build_procedure.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/widgets/pc_build_workbench.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_BUILD')) {
      final loader = FontLoader('Review');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
          ),
        ),
      );
      await loader.load();
    }
  });
  test('every build and wiring item has a complete physical procedure', () {
    for (final sim in [
      SimulationData.getPcAssembly(),
      SimulationData.getCableManagement(),
    ]) {
      for (final item in sim.items.where((i) => i.isRequired)) {
        final operations = PcBuildProcedure.stepsFor(item.id);
        expect(operations.length, greaterThanOrEqualTo(4));
        expect(
          operations.every((o) => PcBuildProcedure.tools.contains(o.tool)),
          isTrue,
        );
        if (item.category != 'diagnostic') {
          final expectedPlacements = switch (item.id) {
            'front_panel' => 4,
            'sata_cable' => 2,
            _ => 1,
          };
          expect(
            operations.where((o) => o.place),
            hasLength(expectedPlacements),
          );
        }
      }
    }
  });

  test('assembly seats every circuit before its functional test', () {
    final steps = PcBuildProcedure.stepsFor('assembly_test');
    final powerOn = steps.indexWhere((step) => step.result.isNotEmpty);
    final seated = steps
        .take(powerOn)
        .where((step) => step.place)
        .map((step) => step.dropToken)
        .toSet();
    expect(seated, containsAll(PcBuildProcedure.requiredConnections));
    expect(seated, hasLength(13));
    expect(
      steps.where((step) => step.dropToken?.startsWith('front_') == true),
      hasLength(4),
    );
  });

  test('case component layers keep realistic orientation and proportions', () {
    expect(PcBuildProcedure.quarterTurns('ram'), 1);
    expect(PcBuildProcedure.quarterTurns('ssd'), 1);
    expect(PcBuildProcedure.quarterTurns('gpu'), 0);
    final ram = PcBuildProcedure.rects['ram']!;
    final ssd = PcBuildProcedure.rects['ssd']!;
    final gpu = PcBuildProcedure.rects['gpu']!;
    double screenAspect(Rect rect) => rect.width * (1672 / 941) / rect.height;
    expect(ram.width, inInclusiveRange(.009, .012));
    expect(PcBuildProcedure.targetRect('ram').contains(ram.center), isTrue);
    expect(screenAspect(ssd), closeTo(250 / 315, .01));
    expect(screenAspect(gpu), closeTo(2172 / 724, .02));
    expect(ram.center.dx, closeTo(.456, .002));
    expect(ram.top, closeTo(.211, .002));
    expect(ram.bottom, closeTo(.474, .002));
    expect(ssd.center.dx, closeTo(.653, .002));
    expect(gpu.left, closeTo(.245, .001));
    expect(gpu.bottom, lessThanOrEqualTo(.72));
    for (final rect in PcBuildProcedure.rects.values) {
      expect(const Rect.fromLTWH(0, 0, 1, 1).contains(rect.topLeft), isTrue);
      expect(rect.right, lessThanOrEqualTo(1));
      expect(rect.bottom, lessThanOrEqualTo(1));
    }
  });

  test('case hardware uses the correct mounting fastener counts', () {
    expect(PcBuildProcedure.fasteners['motherboard'], hasLength(9));
    expect(PcBuildProcedure.fasteners['cpu_fan'], hasLength(4));
    expect(PcBuildProcedure.fasteners['gpu'], hasLength(2));
    expect(PcBuildProcedure.fasteners['ssd'], hasLength(4));
    expect(PcBuildProcedure.fasteners['psu'], hasLength(4));
    expect(PcBuildProcedure.fasteners['ram'], isNull);
    expect(PcBuildProcedure.fasteners['cpu'], isNull);
    expect(
      PcBuildProcedure.fasteners['motherboard']!.toSet(),
      equals({
        const Offset(.309, .191),
        const Offset(.438, .191),
        const Offset(.509, .191),
        const Offset(.281, .483),
        const Offset(.394, .489),
        const Offset(.509, .483),
        const Offset(.281, .676),
        const Offset(.394, .688),
        const Offset(.509, .676),
      }),
    );
  });

  test('front-panel leads have four distinct pin-matching drops', () {
    expect(PcBuildProcedure.frontPanelDropTokens, hasLength(4));
    expect(PcBuildProcedure.frontPanelDropTokens.values.toSet(), hasLength(4));
    expect(
      PcBuildProcedure.frontPanelDropTokens.values,
      everyElement(
        predicate<String>(PcBuildProcedure.frontPanelLeadNames.containsKey),
      ),
    );
  });

  test('final cable test requires external leads before power-on', () {
    final operations = PcBuildProcedure.operations['cable_inspection']!;
    expect(
      operations
          .where((operation) => operation.place)
          .map((operation) => operation.dropToken),
      orderedEquals(['test_display', 'test_keyboard', 'test_mains']),
    );
    expect(
      operations.any(
        (operation) =>
            operation.label.contains('PSU ON') &&
            operation.label.contains('case power button'),
      ),
      isTrue,
    );
  });

  test('both SATA data ends require their own keyed drop', () {
    final drops = PcBuildProcedure.operations['sata_cable']!
        .where((operation) => operation.place)
        .toList();
    expect(
      drops.map((operation) => operation.dropToken),
      orderedEquals(['sata_data_drive', 'sata_data_board']),
    );
    expect(drops.map((operation) => operation.requiredQuarterTurns), [0, 2]);
  });

  testWidgets('system unit rotates between open side and rear panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final simulation = SimulationData.getCableManagement();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PcBuildWorkbench(
            items: simulation.items,
            cabling: true,
            completed: const <String>{},
            onMistake: (_) {},
            onCompleteStep: (_) => true,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('system-unit-open-side')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rotate-system-unit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('system-unit-rear')), findsOneWidget);
    expect(find.text('REAR PANEL • EXTERNAL PORTS AND PSU'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rotate-system-unit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('system-unit-open-side')), findsOneWidget);
  });

  test('every component has a deliberate installation path', () {
    for (final id in PcBuildProcedure.rects.keys) {
      expect(PcBuildProcedure.installStartOffset(id), isNot(Offset.zero));
      expect(
        PcBuildProcedure.installDuration(id).inMilliseconds,
        greaterThanOrEqualTo(700),
      );
      expect(PcBuildProcedure.placementOperation[id], isNotNull);
      expect(PcBuildProcedure.fitChecks[id], hasLength(3));
      expect(
        PcBuildProcedure
            .operations[id]![PcBuildProcedure.placementOperation[id]!]
            .place,
        isTrue,
      );
    }
  });

  for (final cabling in [false, true]) {
    for (final size in [const Size(640, 320), const Size(1280, 800)]) {
      testWidgets(
        'complete ${cabling ? 'wiring' : 'build'} uses tools and oriented drops at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final simulation = cabling
              ? SimulationData.getCableManagement()
              : SimulationData.getPcAssembly();
          final capture = GlobalKey();
          final completed = <String>{};
          final mistakes = <String>[];
          late StateSetter update;
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: ThemeData(
                  fontFamily: const bool.fromEnvironment('CAPTURE_BUILD')
                      ? 'Review'
                      : null,
                ),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return PcBuildWorkbench(
                        items: simulation.items,
                        cabling: cabling,
                        completed: completed,
                        onMistake: mistakes.add,
                        onCompleteStep: (id) {
                          update(() => completed.add(id));
                          return true;
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('build-hotspot')));
          await tester.pump();
          expect(mistakes, hasLength(1));
          expect(completed, isEmpty);
          for (final item in simulation.items.where((i) => i.isRequired)) {
            final steps = PcBuildProcedure.stepsFor(item.id);
            var connectorTurns = 1;
            for (var n = 0; n < steps.length; n++) {
              final step = steps[n];
              final tool = find.byKey(ValueKey('build-tool-${item.id}'));
              await tester.ensureVisible(tool);
              await tester.tap(tool);
              await tester.pumpAndSettle();
              await tester.tap(find.text(step.tool).last);
              await tester.pumpAndSettle();
              if (step.place) {
                final dropToken =
                    step.dropToken ??
                    (item.id == 'front_panel'
                        ? PcBuildProcedure.frontPanelDropTokens[n] ?? item.id
                        : item.id);
                final isFrontPanelLead = PcBuildProcedure.frontPanelLeadNames
                    .containsKey(dropToken);
                if (isFrontPanelLead) {
                  final wrongToken = PcBuildProcedure.frontPanelLeadNames.keys
                      .firstWhere((token) => token != dropToken);
                  final wrongSource = find.byWidgetPredicate(
                    (w) => w is Draggable<String> && w.data == wrongToken,
                  );
                  await tester.ensureVisible(wrongSource);
                  final previousMistakes = mistakes.length;
                  await tester.dragFrom(
                    tester.getCenter(wrongSource),
                    tester.getCenter(
                          find.byKey(const ValueKey('build-drop-target')),
                        ) -
                        tester.getCenter(wrongSource),
                  );
                  await tester.pumpAndSettle();
                  expect(mistakes.length, previousMistakes + 1);
                }
                final requiredTurns = step.requiredQuarterTurns ?? 0;
                final rotate = find.byKey(const ValueKey('rotate-build-part'));
                await tester.ensureVisible(rotate);
                while (connectorTurns != requiredTurns) {
                  await tester.tap(rotate);
                  await tester.pump();
                  connectorTurns = (connectorTurns + 1) % 4;
                }
                final source = find.byWidgetPredicate(
                  (w) => w is Draggable<String> && w.data == dropToken,
                );
                await tester.ensureVisible(source);
                await tester.pumpAndSettle();
                await tester.dragFrom(
                  tester.getCenter(source),
                  tester.getCenter(
                        find.byKey(const ValueKey('build-drop-target')),
                      ) -
                      tester.getCenter(source),
                );
              } else {
                if (item.category == 'diagnostic' && n == steps.length - 1) {
                  await tester.tap(find.byKey(const ValueKey('build-hotspot')));
                  await tester.pump();
                  expect(completed, isNot(contains(item.id)));
                  final record = find.byKey(
                    const ValueKey('build-service-record'),
                  );
                  await tester.ensureVisible(record);
                  await tester.enterText(
                    record,
                    'POST detects CPU, DDR4 and SSD. Fan runs; cables clear.',
                  );
                  tester.testTextInput.hide();
                }
                await tester.tap(find.byKey(const ValueKey('build-hotspot')));
              }
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: '${item.id}: $n');
            }
            expect(completed, contains(item.id));
          }
          expect(
            completed,
            hasLength(simulation.items.where((i) => i.isRequired).length),
          );
          expect(
            find.text(cabling ? 'Wiring complete' : 'Build complete'),
            findsOneWidget,
          );
          if (const bool.fromEnvironment('CAPTURE_BUILD')) {
            await tester.runAsync(() async {
              for (final visual in tester.widgetList<Image>(
                find.byType(Image),
              )) {
                await precacheImage(
                  visual.image,
                  tester.element(find.byType(PcBuildWorkbench)),
                );
              }
              await tester.pump();
              final boundary =
                  capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'build/pc-${cabling ? 'wiring' : 'build'}-${size.width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
}
