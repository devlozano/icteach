import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/student_outcomes.dart';
import 'package:icteach/widgets/outcome_chart.dart';
import 'package:icteach/widgets/persistent_workspace.dart';
import 'package:icteach/services/workspace_navigation.dart';

void main() {
  test('survey summary excludes missing and invalid answers', () {
    final summary = RatingSummary([1, 2, 5, 5, null, '5', 0, 6, 2.5]);
    expect(summary.counts, [1, 1, 0, 0, 2]);
    expect(summary.total, 4);
    expect(summary.average, 3.25);
    expect(RatingSummary([]).average, 0);
  });
  for (final width in [360.0, 1280.0]) {
    testWidgets('outcome chart fits width $width and empty results', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OutcomeChart(
                title: 'NC II student results',
                values: {'Passed': 0, 'No recorded pass': 0},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('No responses or records yet.'), findsOneWidget);
      for (final bar in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      )) {
        expect(bar.value, 0);
      }
    });
  }
  testWidgets(
    'staff navigation remains available on detail pages and returns home',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [WorkspaceNavigation.instance],
          builder: (context, child) => PersistentWorkspace(child: child!),
          home: Builder(
            builder: (context) {
              PersistentWorkspace.register(
                context,
                SizedBox(
                  width: 256,
                  child: Material(
                    child: TextButton(
                      onPressed: () => PersistentWorkspace.returnHome(
                        context,
                        () => selected = true,
                      ),
                      child: const Text('Fixed navigation'),
                    ),
                  ),
                ),
              );
              return Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('Detail page')),
                    ),
                  ),
                  child: const Text('Open detail'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('Fixed navigation'), findsOneWidget);
      expect(find.text('Detail page'), findsOneWidget);
      await tester.tap(find.text('Fixed navigation'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(find.text('Open detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
