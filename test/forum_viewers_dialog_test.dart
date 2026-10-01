import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/forum_viewers_dialog.dart';

void main() {
  testWidgets('viewer dialog presents rich viewer details on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForumViewersDialog(
            viewers: Stream.value([
              {
                'name': 'Maria Santos',
                'role': 'teacher',
                'viewedAt': DateTime(2026, 10, 1, 9, 30),
              },
              {
                'name': 'Juan Cruz',
                'role': 'student',
                'viewedAt': DateTime(2026, 10, 1, 9, 35),
              },
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Viewed by'), findsOneWidget);
    expect(find.text('2 viewers'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Juan Cruz'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.textContaining('Viewed Oct 1'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewer dialog has a designed empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForumViewersDialog(viewers: Stream.value(const [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No other viewers yet'), findsOneWidget);
    expect(find.textContaining('Viewer accounts'), findsOneWidget);
  });
}
