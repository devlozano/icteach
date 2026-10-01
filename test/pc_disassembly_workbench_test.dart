import 'package:icteach/widgets/pc_disassembly_mechanics.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/widgets/drag_drop_simulation.dart';
import 'package:icteach/widgets/pc_disassembly_workbench.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_DISASSEMBLY')) {
      final font = FontLoader('Roboto');
      font.addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/roboto-regular.ttf').readAsBytes(),
          ),
        ),
      );
      await font.load();
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });

  Future<void> selectTool(WidgetTester tester, String tool) async {
    final field = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tool).last);
    await tester.pumpAndSettle();
  }

  Future<void> action(WidgetTester tester, {bool settle = true}) async {
    final button = find.byKey(const ValueKey('disassembly-action'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> dragPart(
    WidgetTester tester,
    String kind, {
    bool accept = true,
    bool settle = true,
    PointerDeviceKind pointerKind = PointerDeviceKind.touch,
  }) async {
    final source = tester.getCenter(find.byKey(ValueKey('installed-$kind')));
    final tray = tester.getRect(find.byKey(const ValueKey('esd-tray-target')));
    final destination = accept
        ? Offset(tray.center.dx, tray.top + 68)
        : source + const Offset(35, -45);
    final gesture = await tester.startGesture(source, kind: pointerKind);
    await gesture.moveBy(const Offset(12, 0));
    await tester.pump();
    await gesture.moveTo(destination);
    await tester.pump(const Duration(milliseconds: 180));
    if (accept) expect(find.text('Release here'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets(
    'complete service sequence, reject wrong tool, animate removal and reset',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      int completions = 0;
      int? finalScore;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: DragDropSimulation(
                simulation: SimulationData.getPcDisassembly(),
                onComplete: (score, total, passed) {
                  completions++;
                  finalScore = score;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.widget<PcDisassemblyWorkbench>(
        find.byType(PcDisassemblyWorkbench),
      );
      final tools = initial.tools;
      await selectTool(tester, tools['disassembly_gpu']!);
      await action(tester);
      expect(
        tester
            .widget<PcDisassemblyWorkbench>(find.byType(PcDisassemblyWorkbench))
            .removed,
        isEmpty,
      );
      await selectTool(tester, tools['disassembly_safety']!);
      for (var i = 0; i < 6; i++) {
        await action(tester);
      }
      expect(
        tester
            .widget<PcDisassemblyWorkbench>(find.byType(PcDisassemblyWorkbench))
            .removed,
        contains('disassembly_safety'),
      );
      // The currently installed board cannot skip the required GPU service step.
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('installed-motherboard'))) +
            const Offset(10, 10),
      );
      await tester.pumpAndSettle();
      await selectTool(tester, tools['disassembly_gpu']!);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('disassembly-action')),
            )
            .onPressed,
        isNull,
      );
      // Hardware stays installed when dragged before its cables/latch are free.
      final lockedSource = tester.getCenter(
        find.byKey(const ValueKey('installed-gpu')),
      );
      final lockedDestination = tester.getCenter(
        find.byKey(const ValueKey('esd-tray-target')),
      );
      await tester.dragFrom(lockedSource, lockedDestination - lockedSource);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stored-gpu')), findsNothing);
      initial.transformationController!.value = Matrix4.identity();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('installed-gpu')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await action(tester);
      }
      expect(find.byKey(const ValueKey('stored-gpu')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('disassembly-action')),
            )
            .onPressed,
        isNull,
      );
      initial.transformationController!.value = Matrix4.diagonal3Values(
        1.1,
        1.1,
        1,
      );
      await tester.pumpAndSettle();
      await dragPart(tester, 'gpu', accept: false);
      expect(find.byKey(const ValueKey('installed-gpu')), findsOneWidget);
      expect(find.byKey(const ValueKey('stored-gpu')), findsNothing);
      await dragPart(
        tester,
        'gpu',
        settle: false,
        pointerKind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const ValueKey('stored-gpu')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('disassembly-action')),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('installed-gpu')), findsNothing);
      expect(find.byKey(const ValueKey('stored-gpu')), findsOneWidget);
      expect(completions, 0);
      initial.transformationController!.value = Matrix4.identity();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(PcDisassemblyWorkbench));
        for (final visual in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(visual.image, context);
        }
      });
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('CAPTURE_DISASSEMBLY')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'tmp/disassembly-open-review.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      for (final entry in {
        'storage': 3,
        'psu': 3,
        'cooler': 5,
        'ram': 3,
        'cpu': 3,
        'motherboard': 4,
      }.entries) {
        await selectTool(tester, tools['disassembly_${entry.key}']!);
        await tester.tap(find.byKey(ValueKey('installed-${entry.key}')));
        await tester.pumpAndSettle();
        for (var i = 0; i < entry.value - 1; i++) {
          await action(tester);
        }
        await dragPart(tester, entry.key);
        expect(find.byKey(ValueKey('installed-${entry.key}')), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(completions, 0);
      await selectTool(tester, tools['disassembly_inventory']!);
      for (var i = 0; i < 4; i++) {
        await action(tester);
      }
      expect(completions, 1);
      expect(finalScore, isNotNull);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reset activity'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PcDisassemblyWorkbench>(find.byType(PcDisassemblyWorkbench))
            .removed,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('installed-gpu')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion completes safety without waiting for animation', (
    tester,
  ) async {
    var completed = 0;
    final sim = SimulationData.getPcDisassembly();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PcDisassemblyWorkbench(
              items: sim.items,
              removed: const {},
              tools: {for (final item in sim.items) item.id: 'ESD tools'},
              onCompleteStep: (_, _) {
                completed++;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await selectTool(tester, 'ESD tools');
    for (var i = 0; i < 5; i++) {
      await action(tester);
    }
    await action(tester, settle: false);
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion commits a valid drop immediately', (
    tester,
  ) async {
    final sim = SimulationData.getPcDisassembly();
    final removed = <String>{'disassembly_safety'};
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PcDisassemblyWorkbench(
              items: sim.items,
              removed: removed,
              tools: {for (final item in sim.items) item.id: 'ESD tools'},
              onCompleteStep: (id, _) {
                completions++;
                removed.add(id);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await selectTool(tester, 'ESD tools');
    await tester.tap(find.byKey(const ValueKey('installed-gpu')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await action(tester);
    }
    await dragPart(tester, 'gpu', settle: false);
    expect(completions, 1);
    expect(removed, contains('disassembly_gpu'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'service hotspots animate each RAM clip and preserve released state until drop',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sim = SimulationData.getPcDisassembly();
      final removed = <String>{
        'disassembly_safety',
        'disassembly_gpu',
        'disassembly_storage',
        'disassembly_psu',
        'disassembly_cooler',
      };
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PcDisassemblyWorkbench(
              items: sim.items,
              removed: removed,
              tools: {for (final item in sim.items) item.id: 'ESD tools'},
              onCompleteStep: (_, _) {
                completions++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await selectTool(tester, 'ESD tools');
      await tester.tap(find.byKey(const ValueKey('installed-ram')));
      await tester.pumpAndSettle();
      PcDisassemblyMechanicsPainter mechanics() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<PcDisassemblyMechanicsPainter>()
          .single;
      final upper = tester.getCenter(
        find.byKey(const ValueKey('pc-service-point')),
      );
      await tester.tap(find.byKey(const ValueKey('pc-service-point')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(mechanics().p('ram', 0), greaterThan(0));
      expect(mechanics().p('ram', 0), lessThan(1));
      expect(mechanics().p('ram', 1), 0);
      expect(completions, 0);
      await tester.pumpAndSettle();
      expect(mechanics().p('ram', 0), 1);
      final lower = tester.getCenter(
        find.byKey(const ValueKey('pc-service-point')),
      );
      expect(lower.dy, greaterThan(upper.dy));
      await tester.tap(find.byKey(const ValueKey('pc-service-point')));
      await tester.pumpAndSettle();
      expect(mechanics().p('ram', 0), 1);
      expect(mechanics().p('ram', 1), 1);
      expect(find.byKey(const ValueKey('pc-service-point')), findsNothing);
      await dragPart(tester, 'ram', accept: false);
      expect(completions, 0);
      expect(mechanics().p('ram', 0), 1);
      expect(mechanics().p('ram', 1), 1);
      await dragPart(tester, 'ram');
      expect(completions, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
