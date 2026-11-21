import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/screens/student/learning_continuation_page.dart';
import 'package:icteach/services/learning_continuation_service.dart';

const item = LearningDestination('one', 'First activity');
const other = LearningDestination('two', 'Second activity');
Widget app(LearningContinuationPage page) => MaterialApp(home: page);

void main() {
  testWidgets('quiz and simulation handoff UI fits a narrow Android screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        LearningContinuationPage(
          classId: 'class',
          moduleId: 'module',
          loadDestinations: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue to Quiz'), findsWidgets);
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      app(
        LearningContinuationPage(
          classId: 'class',
          quizId: 'quiz',
          loadDestinations: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue to Simulation'), findsWidgets);
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic forwarding preserves student home for Android Back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LearningContinuationPage(
                    classId: 'class',
                    moduleId: 'lesson',
                    loadDestinations: () async => [item],
                    destinationBuilder: (_) async => Scaffold(
                      appBar: AppBar(title: const Text('Assigned quiz')),
                      body: const Text('Quiz screen'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open learning flow'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open learning flow'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz screen'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open learning flow'), findsOneWidget);
    expect(find.text('Quiz screen'), findsNothing);
  });

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
    expect(find.text('Module complete'), findsOneWidget);
    expect(find.text('Module'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Simulation'), findsOneWidget);
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
    await tester.ensureVisible(find.text('First activity'));
    await tester.tap(find.text('First activity'));
    await tester.tap(find.text('First activity'));
    expect(opens, 1);
    pending.completeError(StateError('Activity locked'));
    await tester.pumpAndSettle();
    expect(find.text('Activity locked'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Activity locked'), findsNothing);
    await tester.ensureVisible(find.text('First activity'));
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
