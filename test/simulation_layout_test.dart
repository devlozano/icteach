import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/utils/app_theme.dart';
import 'package:icteach/widgets/drag_drop_simulation.dart';
import 'package:icteach/widgets/draggable_item_widget.dart';
import 'package:icteach/widgets/drop_target_widget.dart';

const _reviewFont = String.fromEnvironment('UI_REVIEW_FONT');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (_reviewFont.isNotEmpty) {
      final loader = FontLoader('Review');
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File(_reviewFont).readAsBytes()),
        ),
      );
      await loader.load();
      const icons = String.fromEnvironment('UI_REVIEW_ICONS');
      if (icons.isNotEmpty) {
        final loader = FontLoader('MaterialIcons');
        loader.addFont(
          Future.value(ByteData.sublistView(await File(icons).readAsBytes())),
        );
        await loader.load();
      }
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });
  for (final size in [
    const Size(640, 320),
    const Size(740, 360),
    const Size(844, 390),
    const Size(1024, 600),
    const Size(1280, 800),
  ]) {
    for (final simulation in SimulationData.getAllSimulations()) {
      testWidgets('${simulation.id} landscape ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        var theme = AppTheme.light;
        if (_reviewFont.isNotEmpty) {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Review'),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                appBar: AppBar(title: Text(simulation.title)),
                body: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: DragDropSimulation(
                      simulation: simulation,
                      onComplete: (_, _, _) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (find.byType(CheckboxListTile).evaluate().isNotEmpty) {
          if (find.byType(CheckboxListTile).evaluate().length == 1) {
            for (var i = 0; i < 3; i++) {
              await tester.tap(find.byType(CheckboxListTile));
              await tester.pump();
              await tester.tap(find.text(i < 2 ? 'Next' : 'Start'));
              await tester.pump();
            }
          } else {
            for (var i = 0; i < 3; i++) {
              await tester.tap(find.byType(CheckboxListTile).at(i));
              await tester.pump();
            }
            await tester.tap(
              find.text(
                simulation.id == 'sim_coc1_assembly'
                    ? 'Enter assembly bay'
                    : 'Start controlled installation',
              ),
            );
          }
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(find.text('Place on target'), findsNothing);
        expect(find.text('Drop Here'), findsNothing);
        if (simulation.id == 'sim_coc2_crimping') {
          expect(find.text('Straight-through'), findsOneWidget);
          expect(find.text('Crossover (10/100)'), findsOneWidget);
          await tester.tap(find.text('Straight-through'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Strip outer jacket'), findsOneWidget);
          expect(find.byKey(const ValueKey('cable-work-area')), findsOneWidget);
          expect(tester.takeException(), isNull);
          return;
        }
        expect(find.byType(DropTargetWidget).evaluate().length, greaterThan(1));
        expect(find.byType(SingleChildScrollView), findsNothing);
        final bench = tester.getRect(find.byType(InteractiveViewer));
        expect(bench.width, greaterThan(size.width * .60));
        final targets = find.byType(DropTargetWidget);
        for (final element in targets.evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(rect.left, greaterThanOrEqualTo(bench.left));
          expect(rect.right, lessThanOrEqualTo(bench.right + 1));
          expect(rect.top, greaterThanOrEqualTo(bench.top));
          expect(rect.bottom, lessThanOrEqualTo(bench.bottom + 1));
        }
        if (simulation.id != 'sim_coc1_assembly') {
          final rects = targets
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget)))
              .toList();
          for (var a = 0; a < rects.length; a++) {
            for (var b = a + 1; b < rects.length; b++) {
              expect(
                rects[a].overlaps(rects[b]),
                false,
                reason: 'Targets $a and $b overlap in ${simulation.id}',
              );
            }
          }
        }
        final next = tester.widget<IconButton>(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Next parts',
          ),
        );
        if (next.onPressed != null) {
          final first = tester
              .widget<DraggableItemWidget>(
                find.byType(DraggableItemWidget).first,
              )
              .item
              .id;
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Next parts',
            ),
          );
          await tester.pump();
          expect(
            tester
                .widget<DraggableItemWidget>(
                  find.byType(DraggableItemWidget).first,
                )
                .item
                .id,
            isNot(first),
          );
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Previous parts',
            ),
          );
          await tester.pump();
        }
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Workbench guide',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Using the workbench'), findsOneWidget);
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(DraggableItemWidget).first);
        await tester.pumpAndSettle();
        expect(find.textContaining('Resource:'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        if (simulation.type == 'identification') {
          await tester.tap(find.byType(DropTargetWidget).first);
          await tester.pumpAndSettle();
          expect(find.text('Inspect specimen'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (w) =>
                  w is IconButton && w.tooltip == 'Identification confidence',
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('High'));
          await tester.tap(find.text('High'));
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (_reviewFont.isNotEmpty &&
            [
              'sim_coc1_assembly',
              'sim_coc1_cabling',
              'sim_coc1_identification',
              'sim_coc2_crimping',
            ].contains(simulation.id)) {
          await tester.runAsync(() async {
            final gameContext = tester.element(find.byType(DragDropSimulation));
            for (final visual in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(visual.image, gameContext);
            }
            await tester.pump();
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage();
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/ui-review/${simulation.id}-${size.width.toInt()}x${size.height.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }

  testWidgets(
    'landscape tray supports resource checks and dragging; rotation preserves progress',
    (tester) async {
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final simulation = SimulationData.getSimulationById('sim_coc1_cabling')!;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DragDropSimulation(
              simulation: simulation,
              onComplete: (_, _, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var step = 1; step <= 2; step++) {
        while (tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (w) => w is IconButton && w.tooltip == 'Previous parts',
                  ),
                )
                .onPressed !=
            null) {
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Previous parts',
            ),
          );
          await tester.pump();
        }
        Finder part() => find.byWidgetPredicate(
          (w) => w is DraggableItemWidget && w.item.step == step,
        );
        while (part().evaluate().isEmpty) {
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (w) => w is IconButton && w.tooltip == 'Next parts',
                  ),
                )
                .onPressed,
            isNotNull,
          );
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Next parts',
            ),
          );
          await tester.pump();
        }
        final item = tester.widget<DraggableItemWidget>(part()).item;
        final target = find.byWidgetPredicate(
          (w) => w is DropTargetWidget && w.slotId == item.correctSlot,
        );
        if (step == 1) {
          await tester.dragFrom(
            tester.getCenter(part()),
            tester.getCenter(target) - tester.getCenter(part()),
          );
          await tester.pump();
          expect(find.textContaining('Resource check failed'), findsOneWidget);
          ScaffoldMessenger.of(
            tester.element(find.byType(DragDropSimulation)),
          ).clearSnackBars();
          await tester.pump(const Duration(seconds: 5));
        }
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Connector key + latch inspection').last);
        await tester.pumpAndSettle();
        await tester.dragFrom(
          tester.getCenter(part()),
          tester.getCenter(target) - tester.getCenter(part()),
        );
        await tester.pump();
        expect(tester.widget<DropTargetWidget>(target).placedItem?.id, item.id);
        ScaffoldMessenger.of(
          tester.element(find.byType(DragDropSimulation)),
        ).clearSnackBars();
        await tester.pump(const Duration(seconds: 5));
        tester.view.physicalSize = const Size(360, 740);
        await tester.pump();
        expect(find.text('Turn your screen sideways'), findsOneWidget);
        tester.view.physicalSize = const Size(740, 360);
        await tester.pump();
        expect(tester.widget<DropTargetWidget>(target).placedItem?.id, item.id);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
