import 'package:icteach/models/quiz_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/activity_preparation_gate.dart';
import 'package:icteach/widgets/user_roles_button.dart';
import 'package:icteach/data/simulation_data.dart';

void main() {
  test('advanced module-related labs are present', () {
    final ids = SimulationData.getAllSimulations().map((s) => s.id).toSet();
    for (final keyword in [
      'os_install',
      'maintenance',
      'repair',
      'diagnostics',
    ]) {
      expect(ids.any((id) => id.contains(keyword)), isTrue, reason: keyword);
    }
  });
  for (final learned in [false, true]) {
    for (final practiced in [false, true]) {
      testWidgets(
        'quiz is scored-only regardless of lesson=$learned and practice=$practiced',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ActivityPreparationGate(
                classId: 'class',
                type: 'quiz',
                contentId: 'quiz',
                title: 'Theory quiz',
                stateLoader: () async => {
                  'configured': true,
                  'module': 'Lesson',
                  'learned': learned,
                  'practiced': practiced,
                  'theoryDone': true,
                },
                sessionBuilder: (_) => const SizedBox(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = tester.widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              'Start scored quiz (one attempt)',
            ),
          );
          expect(button.onPressed, isNotNull);
          expect(find.textContaining('Practice'), findsNothing);
          expect(find.byType(OutlinedButton), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final learned in [false, true]) {
    for (final practiced in [false, true]) {
      testWidgets(
        'simulation still needs lesson=$learned practice=$practiced',
        (tester) async {
          final quiz = QuizModel(
            id: 'q',
            classId: 'c',
            title: 'Theory',
            description: '',
            questions: [],
            timeLimit: 0,
            totalPoints: 0,
            isPublished: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: ActivityPreparationGate(
                classId: 'c',
                type: 'simulation',
                contentId: 's',
                title: 'Simulation',
                stateLoader: () async => {
                  'configured': true,
                  'module': 'Lesson',
                  'learned': learned,
                  'practiced': practiced,
                  'theoryDone': true,
                  'quiz': quiz,
                },
                sessionBuilder: (_) => const SizedBox(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = tester.widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              'Part 2: interactive simulation assessment',
            ),
          );
          expect(button.onPressed != null, learned && practiced);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('missing instructor mapping blocks simulation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityPreparationGate(
          classId: 'class',
          type: 'simulation',
          contentId: 'quiz',
          title: 'Theory quiz',
          stateLoader: () async => {'configured': false},
          sessionBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('waiting for teacher setup'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets('loading failure remains blocked and retry works', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityPreparationGate(
          classId: 'class',
          type: 'quiz',
          contentId: 'quiz',
          title: 'Theory quiz',
          stateLoader: () async {
            calls++;
            throw StateError('offline');
          },
          sessionBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to prepare activity'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets(
    'role explanation includes trainer and student responsibilities',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserRolesButton())),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Trainer\n'), findsOneWidget);
      expect(find.textContaining('Student\n'), findsOneWidget);
      expect(find.textContaining('Administrator\n'), findsOneWidget);
    },
  );
}
