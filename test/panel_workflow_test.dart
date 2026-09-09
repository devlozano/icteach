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
        'assessment requires lesson=$learned and practice=$practiced',
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
          expect(button.onPressed != null, learned && practiced);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('missing instructor mapping blocks activity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityPreparationGate(
          classId: 'class',
          type: 'quiz',
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
