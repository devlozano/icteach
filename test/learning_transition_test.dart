import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/screens/student/learning_continuation_page.dart';
import 'package:icteach/services/learning_continuation_service.dart';

const item = LearningDestination('one', 'First activity');
const other = LearningDestination('two', 'Second activity');
Widget app(LearningContinuationPage page) => MaterialApp(home: page);

void main() {
  testWidgets('single activity shows loading and forwards automatically', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(
      app(
        LearningContinuationPage(
          classId: 'class',
          moduleId: 'lesson',
          loadDestinations: () async => [item],
          destinationBuilder: (_) => pending.future,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Opening your next activity...'), findsOneWidget);
    expect(find.text('Module → Lesson → Quiz → Simulation'), findsOneWidget);
    pending.complete(const Scaffold(body: Text('Next screen')));
    await tester.pumpAndSettle();
    expect(find.text('Next screen'), findsOneWidget);
  });

  testWidgets('failed load can retry and missing links can refresh', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      app(
        LearningContinuationPage(
          classId: 'class',
          moduleId: 'lesson',
          loadDestinations: () async {
            if (++loads == 1) throw Exception('offline');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your progress is saved.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(loads, 3);
  });

  testWidgets('multiple taps launch once and opening failure can retry', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    var opens = 0;
    await tester.pumpWidget(
      app(
        LearningContinuationPage(
          classId: 'class',
          quizId: 'quiz',
          loadDestinations: () async => [item, other],
          destinationBuilder: (_) {
            opens++;
            return opens == 1
                ? pending.future
                : Future.value(const Scaffold(body: Text('Ready')));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('First activity'));
    await tester.tap(find.text('First activity'));
    expect(opens, 1);
    pending.completeError(StateError('Activity locked'));
    await tester.pumpAndSettle();
    expect(find.text('Activity locked'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Activity locked'), findsNothing);
    await tester.tap(find.text('First activity'));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('leaving while loading never navigates after disposal', (
    tester,
  ) async {
    final pending = Completer<List<LearningDestination>>();
    var opens = 0;
    await tester.pumpWidget(
      app(
        LearningContinuationPage(
          classId: 'class',
          moduleId: 'lesson',
          loadDestinations: () => pending.future,
          destinationBuilder: (_) async {
            opens++;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: Text('Left page')));
    pending.complete([item]);
    await tester.pumpAndSettle();
    expect(opens, 0);
    expect(find.text('Left page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow connection times out and late response does not navigate', (
    tester,
  ) async {
    final pending = Completer<List<LearningDestination>>();
    var opens = 0;
    await tester.pumpWidget(
      app(
        LearningContinuationPage(
          classId: 'class',
          moduleId: 'lesson',
          loadDestinations: () => pending.future,
          destinationBuilder: (_) async {
            opens++;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    pending.complete([item]);
    await tester.pumpAndSettle();
    expect(opens, 0);
  });
}
