import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/rj45_session.dart';
import 'package:icteach/widgets/rj45_workbench.dart';

void main() {
  testWidgets('manual two-end cable workflow delays feedback until tester scan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var submissions = 0;
    const capture = bool.fromEnvironment('RJ45_CAPTURE');
    final boundary = GlobalKey();
    if (capture) {
      await tester.runAsync(() async {
        final font = FontLoader('Review')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/roboto-regular.ttf').readAsBytes(),
              ),
            ),
          );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
        await icons.load();
      });
    }
    Future<void> screenshot(String name) async {
      if (!capture) return;
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final context = tester.element(find.byType(Rj45Workbench));
      await tester.runAsync(() async {
        for (final image in images) {
          await precacheImage(image.image, context);
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/' + name + '.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: capture ? 'Review' : null),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: Material(
              color: Colors.white,
              child: Rj45Workbench(
                onComplete: (score, total, passed) {
                  submissions++;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Straight-through'));
    await tester.pumpAndSettle();
    await screenshot('rj45-assets-jacket');
    Future<void> drag(String data, Finder target) async {
      final source = find.byWidgetPredicate(
        (w) => w is Draggable<String> && w.data == data,
      );
      await tester.ensureVisible(source);
      await tester.ensureVisible(target);
      await tester.drag(
        source,
        tester.getCenter(target) - tester.getCenter(source),
      );
      await tester.pumpAndSettle();
    }

    for (var e = 0; e < 2; e++) {
      await drag('stripper', find.byKey(const ValueKey('cable-work-area')));
      if (e == 0) await screenshot('rj45-assets-spline');
      await drag('cutters', find.byKey(const ValueKey('cable-work-area')));
      for (final pair in ['orange', 'green', 'blue', 'brown']) {
        await tester.tap(find.text('Untwist $pair pair'));
        await tester.pumpAndSettle();
      }
      final order = e == 0 ? [1, 0, 2, 5, 4, 3, 6, 7] : Rj45Session.t568b;
      for (var p = 0; p < 8; p++) {
        await drag('wire:${order[p]}', find.byKey(ValueKey('wire-pin-$p')));
      }
      expect(find.textContaining('FAIL'), findsNothing);
      await tester.tap(find.text('Keep this order and trim'));
      await tester.pumpAndSettle();
      await drag('cutters', find.byKey(const ValueKey('cable-work-area')));
      await drag('bundle', find.byKey(const ValueKey('empty-rj45')));
      await drag('crimper', find.byKey(const ValueKey('cable-work-area')));
      if (e == 0) {
        await tester.tap(find.text('Prepare the other end'));
        await tester.pumpAndSettle();
      }
    }
    await screenshot('rj45-tester-unplugged');
    expect(find.text('Empty socket'), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Run LAN test'),
          )
          .onPressed,
      isNull,
    );
    await drag('end:0', find.byKey(const ValueKey('tester-port-0')));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Run LAN test'),
          )
          .onPressed,
      isNull,
    );
    await drag('end:1', find.byKey(const ValueKey('tester-port-1')));
    expect(find.textContaining('FAIL'), findsNothing);
    expect(submissions, 0);
    await tester.tap(find.text('Run LAN test'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('FAIL • Re-terminate the cable'), findsOneWidget);
    expect(find.textContaining('1→2  2→1'), findsOneWidget);
    await screenshot('rj45-tester-result');
    expect(submissions, 0);
    expect(tester.takeException(), isNull);
  });
}
