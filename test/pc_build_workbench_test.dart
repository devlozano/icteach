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

  test('motherboard screws only follow board placement', () {
    final steps = PcBuildProcedure.stepsFor('motherboard');
    final placement = steps.indexWhere((step) => step.place);
    expect(placement, PcBuildProcedure.placementOperation['motherboard']);
    expect(
      steps.take(placement).any((step) => step.tool == PcBuildProcedure.driver),
      isFalse,
    );
    expect(
      steps
          .skip(placement + 1)
          .where((step) => step.tool == PcBuildProcedure.driver),
      hasLength(9),
    );
  });

  test('wiring procedure seats every circuit before final verification', () {
    final seated = {
      for (final id in PcBuildProcedure.connectionSequence)
        for (final step in PcBuildProcedure.stepsFor(id))
          if (step.place) step.dropToken,
    };
    expect(seated, containsAll(PcBuildProcedure.requiredConnections));
    expect(seated, hasLength(13));
    expect(
      seated.where((token) => token?.startsWith('front_') == true),
      hasLength(4),
    );
  });

  test('case component layers keep realistic orientation and proportions', () {
    expect(PcBuildProcedure.quarterTurns('ram'), 1);
    expect(PcBuildProcedure.quarterTurns('ssd'), 3);
    expect(PcBuildProcedure.quarterTurns('gpu'), 0);
    expect(PcBuildProcedure.quarterTurns('cmos'), 0);
    final ram = PcBuildProcedure.rects['ram']!;
    final ssd = PcBuildProcedure.rects['ssd']!;
    final gpu = PcBuildProcedure.rects['gpu']!;
    final cmos = PcBuildProcedure.rects['cmos']!;
    double screenAspect(Rect rect) => rect.width * (1672 / 941) / rect.height;
    expect(ram.width, inInclusiveRange(.009, .012));
    expect(PcBuildProcedure.targetRect('ram').contains(ram.center), isTrue);
    expect(screenAspect(ssd), closeTo(69.85 / 100, .03));
    expect(screenAspect(gpu), closeTo(2172 / 724, .02));
    expect(ram.center.dx, closeTo(.463, .002));
    expect(ram.top, closeTo(.211, .002));
    expect(ram.bottom, closeTo(.474, .002));
    expect(ssd.center.dx, closeTo(.626, .002));
    expect(gpu.left, closeTo(.228, .001));
    expect(gpu.top, closeTo(.510, .001));
    expect(gpu.bottom, lessThanOrEqualTo(.72));
    expect(cmos.center.dx, closeTo(.432, .001));
    expect(
      cmos.right,
      lessThan(ram.left),
      reason: 'The CMOS battery must clear the DIMM slot and its latches.',
    );
    expect(cmos.center.dy, closeTo(.438, .001));
    expect(
      screenAspect(cmos),
      closeTo(1, .04),
      reason: 'The seated CR2032 must render as a circle, not an oval.',
    );
    final cooler = PcBuildProcedure.rects['cpu_fan']!;
    expect(screenAspect(cooler), closeTo(1, .01));
    expect(cooler.overlaps(cmos), isFalse);
    expect(PcBuildProcedure.rects['cpu']!.overlaps(cmos), isFalse);
    expect(
      PcBuildProcedure.cpuFanHeader.dy,
      lessThan(ram.top),
      reason: 'CPU_FAN must remain above the RAM slot.',
    );
    expect(
      PcBuildProcedure.cpuFanCableExit.dx,
      lessThan(ram.left),
      reason: 'The cooler lead must leave the fan before the DIMM bank.',
    );
    for (final rect in PcBuildProcedure.rects.values) {
      expect(const Rect.fromLTWH(0, 0, 1, 1).contains(rect.topLeft), isTrue);
      expect(rect.right, lessThanOrEqualTo(1));
      expect(rect.bottom, lessThanOrEqualTo(1));
    }
  });

  test('case hardware uses the correct mounting fastener counts', () {
    final gpu = PcBuildProcedure.rects['gpu']!;
    expect(PcBuildProcedure.fasteners['motherboard'], hasLength(9));
    expect(PcBuildProcedure.fasteners['cpu_fan'], isNull);
    expect(PcBuildProcedure.coolerPushPins, hasLength(4));
    expect(PcBuildProcedure.fasteners['gpu'], hasLength(2));
    expect(PcBuildProcedure.fasteners['ssd'], hasLength(4));
    expect(PcBuildProcedure.fasteners['psu'], hasLength(4));
    expect(PcBuildProcedure.fasteners['ram'], isNull);
    expect(PcBuildProcedure.fasteners['cpu'], isNull);
    expect(PcBuildProcedure.fasteners['cmos'], isNull);
    expect(
      PcBuildProcedure.fasteners['gpu'],
      orderedEquals([const Offset(.230, .523), const Offset(.230, .558)]),
    );
    for (final screw in PcBuildProcedure.fasteners['gpu']!) {
      expect(
        screw.dx,
        inInclusiveRange(gpu.left, gpu.left + gpu.width * .08),
        reason: 'GPU screws must land on the rear bracket tabs.',
      );
      expect(
        screw.dy,
        inInclusiveRange(gpu.top, gpu.bottom),
        reason: 'GPU screws must remain vertically aligned with the bracket.',
      );
    }
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
    for (final entry in PcBuildProcedure.fasteners.entries) {
      final component = PcBuildProcedure.rects[entry.key]!;
      for (final screw in entry.value) {
        expect(
          component.contains(screw),
          isTrue,
          reason: '${entry.key} screw $screw must sit inside its mount.',
        );
      }
      final placement = PcBuildProcedure.placementOperation[entry.key]!;
      final securedPoints = PcBuildProcedure.stepsFor(entry.key)
          .skip(placement + 1)
          .where((step) => step.tool == PcBuildProcedure.driver)
          .map((step) => step.point);
      expect(
        securedPoints,
        orderedEquals(entry.value),
        reason: '${entry.key} screw actions must use the rendered screw slots.',
      );
    }
  });

  test('CPU cooler uses four hand-operated push-pin locks, not screws', () {
    final steps = PcBuildProcedure.stepsFor('cpu_fan');
    final placement = PcBuildProcedure.placementOperation['cpu_fan']!;
    final locking = steps.skip(placement + 1).take(4).toList();
    expect(
      locking.map((step) => step.tool),
      everyElement(PcBuildProcedure.hand),
    );
    expect(
      locking.map((step) => step.point),
      orderedEquals(PcBuildProcedure.coolerPushPins),
    );
    expect(
      locking.map((step) => step.label.toLowerCase()).join(' '),
      allOf(contains('rotate'), contains('press'), contains('push pin')),
    );
  });

  test('assembly offers the compatible DDR4 module only', () {
    final memory = SimulationData.getPcAssembly().items.where(
      (item) => item.category == 'memory',
    );
    expect(memory.map((item) => item.id), orderedEquals(['ram']));
    expect(memory.single.specification, contains('DDR4'));
    expect(memory.single.imageUrl, contains('assembly-ram-ddr4'));
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

  test('front-panel plugs form the correct two-row header grid', () {
    const hdd = PcBuildProcedure.frontHddLedPins;
    const powerLed = PcBuildProcedure.frontPowerLedPins;
    const reset = PcBuildProcedure.frontResetSwPins;
    const powerSw = PcBuildProcedure.frontPowerSwPins;
    expect(hdd.dy, reset.dy, reason: 'HDD LED and RESET use the odd-pin row.');
    expect(
      powerLed.dy,
      powerSw.dy,
      reason: 'POWER LED and POWER SW use the even-pin row.',
    );
    expect(hdd.dx, powerLed.dx, reason: 'LED plugs share the left columns.');
    expect(
      reset.dx,
      powerSw.dx,
      reason: 'Switch plugs share the right columns.',
    );
    expect(hdd.dx, lessThan(reset.dx));
    expect(hdd.dy, lessThan(powerLed.dy));
    for (final pins in [hdd, powerLed, reset, powerSw]) {
      expect(PcBuildProcedure.rects['motherboard']!.contains(pins), isTrue);
    }
  });

  test('final functional test connects external leads before power-on', () {
    final operations = PcBuildProcedure.operations['assembly_test']!;
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

  test('final assembly verification does not repeat installed wiring', () {
    final operations = PcBuildProcedure.stepsFor('assembly_test');
    expect(operations, hasLength(6));
    expect(
      operations
          .where((operation) => operation.place)
          .map((operation) => operation.dropToken),
      orderedEquals(['test_display', 'test_keyboard', 'test_mains']),
    );
    expect(
      operations.map((operation) => operation.label).join(' ').toLowerCase(),
      isNot(contains('seat the')),
    );
    expect(
      PcBuildProcedure.stepsFor(
        'cable_inspection',
      ).where((operation) => operation.dropToken != null),
      isEmpty,
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

  test('GPU and SATA cables use separate routing corridors', () {
    final routes = PcBuildProcedure.cableRouteX;
    expect(routes.values.toSet(), hasLength(routes.length));
    expect(routes['gpu_power'], lessThan(routes['sata_cable']!));
    expect(routes['sata_cable'], lessThan(routes['power_cable']!));
    expect(routes['sata_power'], greaterThan(routes['power_cable']!));
  });

  test('SSD endpoints meet the raised side tray without floating', () {
    final ssd = PcBuildProcedure.rects['ssd']!;
    const data = PcBuildProcedure.sataDataDrivePort;
    const power = PcBuildProcedure.sataPowerDrivePort;
    expect(ssd.contains(data), isTrue);
    expect(ssd.contains(power), isTrue);
    expect(data.dy, closeTo(ssd.bottom, .01));
    expect(power.dy, closeTo(ssd.bottom, .01));
    for (final screw in PcBuildProcedure.fasteners['ssd']!) {
      expect(ssd.contains(screw), isTrue);
    }
  });

  test('power and data cable endpoints align with their hardware ports', () {
    final gpu = PcBuildProcedure.rects['gpu']!;
    final ssd = PcBuildProcedure.rects['ssd']!;
    final board = PcBuildProcedure.rects['motherboard']!;
    expect(gpu.contains(PcBuildProcedure.gpuPowerPort), isTrue);
    expect(ssd.contains(PcBuildProcedure.sataDataDrivePort), isTrue);
    expect(ssd.contains(PcBuildProcedure.sataPowerDrivePort), isTrue);
    expect(board.contains(PcBuildProcedure.sataDataBoardPort), isTrue);
    expect(
      PcBuildProcedure.sataDataDrivePort.dx,
      lessThan(PcBuildProcedure.sataPowerDrivePort.dx),
      reason:
          'The narrow SATA data socket sits left of the wider power socket.',
    );
    expect(
      PcBuildProcedure.sataPowerDrivePort.dx -
          PcBuildProcedure.sataDataDrivePort.dx,
      inInclusiveRange(.025, .035),
      reason: 'Both SSD plugs must be centered without overlapping.',
    );
  });

  test('CMOS installation releases the holder before seating positive-up', () {
    final steps = PcBuildProcedure.stepsFor('cmos');
    final placement = steps.indexWhere((step) => step.place);
    expect(placement, PcBuildProcedure.placementOperation['cmos']);
    expect(steps[1].label.toLowerCase(), contains('release'));
    expect(steps[placement].label, contains('positive (+) face visible'));
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
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    await tester.tap(find.byKey(const ValueKey('workbench-zoom-in')));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workbench-center-view')));
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    await tester.tap(find.byKey(const ValueKey('workbench-zoom-in')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('workbench-zoom-out')));
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    await tester.tap(find.byKey(const ValueKey('rotate-system-unit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('system-unit-rear')), findsOneWidget);
    expect(find.byTooltip('Rotate to open side'), findsOneWidget);
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
              final tray = find.byKey(ValueKey('build-tool-${item.id}'));
              expect(
                tray,
                findsOneWidget,
                reason: '${item.id} should be the active build item',
              );
              await tester.ensureVisible(tray);
              final tool = find.byKey(
                ValueKey('select-build-tool-${step.tool}'),
              );
              await tester.ensureVisible(tool);
              await tester.tap(tool);
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
              } else if (step.tool == PcBuildProcedure.driver) {
                final driver = find.byWidgetPredicate(
                  (w) => w is Draggable<String> && w.data == 'tool:phillips-2',
                );
                await tester.ensureVisible(driver);
                await tester.pumpAndSettle();
                await tester.drag(
                  driver,
                  tester.getCenter(
                        find.byKey(const ValueKey('build-screw-target')),
                      ) -
                      tester.getCenter(driver),
                );
              } else {
                if (step.tool == PcBuildProcedure.hand &&
                    (item.id == 'cpu' || item.id == 'ram')) {
                  expect(
                    find.descendant(
                      of: find.byKey(const ValueKey('build-hotspot')),
                      matching: find.byType(Icon),
                    ),
                    findsNothing,
                  );
                }
                if (item.category == 'diagnostic' &&
                    n == steps.length - 1 &&
                    step.label.toLowerCase().startsWith('record')) {
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
              if (!cabling &&
                  step.place &&
                  const {'ram', 'gpu', 'psu'}.contains(item.id)) {
                expect(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget.key is ValueKey<String> &&
                        (widget.key! as ValueKey<String>).value.startsWith(
                          'installed-fastener-${item.id}-',
                        ),
                  ),
                  findsNothing,
                  reason:
                      '${item.id} fasteners must wait for their fastening steps.',
                );
              }
              if (const bool.fromEnvironment('CAPTURE_BUILD') &&
                  (item.id == 'cpu' || item.id == 'ram') &&
                  n == 1) {
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
                  final image =
                      await (capture.currentContext!.findRenderObject()
                              as RenderRepaintBoundary)
                          .toImage();
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    'build/${item.id}-latch-open-${size.width.toInt()}.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
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
          final fastenerCount = PcBuildProcedure.fasteners.values.fold<int>(
            0,
            (total, screws) => total + screws.length,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'installed-fastener-',
                  ),
            ),
            findsNWidgets(fastenerCount),
            reason: 'Every secured screw must remain visible in the case.',
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
