import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/module_access_overview.dart';

void main() {
  const students = [
    ModuleStudentActivity(
      id: '1',
      name: 'Ana Maria Santos with a long family name',
      accessed: true,
      downloaded: true,
      requested: true,
    ),
    ModuleStudentActivity(
      id: '2',
      name: 'Jose Lalata',
      accessed: true,
      requested: true,
    ),
    ModuleStudentActivity(id: '3', name: 'Ben Cruz'),
  ];
  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(1280, 800),
  ]) {
    testWidgets('activity panel expands and fits $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ModuleAccessOverview(
                  students: students,
                  accessed: 2,
                  downloaded: 1,
                  requested: 2,
                  printAction: TextButton(
                    onPressed: () {},
                    child: const Text('Print summary'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(2 / 3, 0.001),
      );
      await tester.ensureVisible(find.text('View student details'));
      await tester.tap(find.text('View student details'));
      await tester.pumpAndSettle();
      expect(find.text('Requested · unconfirmed'), findsOneWidget);
      expect(find.text('Not accessed'), findsOneWidget);
      expect(find.text('Not downloaded'), findsOneWidget);
      expect(
        find.text('Downloaded'),
        findsNWidgets(2),
      ); // Metric label and confirmed student only.
      await tester.ensureVisible(find.text('Ben Cruz'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty activity panel has zero progress and helpful message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModuleAccessOverview(
              students: [],
              accessed: 0,
              downloaded: 0,
              requested: 0,
              printAction: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
    await tester.ensureVisible(find.text('View student details'));
    await tester.tap(find.text('View student details'));
    await tester.pumpAndSettle();
    expect(find.text('No enrolled students'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
