import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:icteach/data/interactive_quizzes.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/data/simulation_step_detail.dart';
import 'package:icteach/data/service_decisions.dart';
import 'package:icteach/models/quiz_model.dart';
import 'package:icteach/screens/student/interactive_quiz_page.dart';
import 'package:icteach/services/learning_path_service.dart';
import 'package:icteach/services/learning_continuation_service.dart';
import 'package:icteach/widgets/simulation_step_lab.dart';

void main() {
  test('interactive result retains its 80 percent passing threshold', () {
    final result = QuizResult(
      quizId: 'interactive_class_sim_coc2_ipconfig',
      classId: 'class',
      studentId: 'student',
      studentName: 'Student',
      score: 7,
      totalPoints: 10,
      userAnswers: [],
      completedAt: DateTime(2026),
      timeSpent: 120,
      passingPercentage: 80,
    );
    expect(result.isPassed, isFalse);
    expect(result.toFirestore()['passingPercentage'], 80);
  });
  for (final activity in [
    SimulationData.getIpConfiguration(),
    SimulationData.getConnectivityDiagnostics(),
  ]) {
    testWidgets('${activity.id} completes all embedded portrait procedures', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      (int, int, bool)? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveQuizWorkbench(
              activity: activity,
              onComplete: (s, t, p) => result = (s, t, p),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> press(String key) async {
        final target = find.byKey(ValueKey(key));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      for (final item in activity.items.where((i) => i.isRequired)) {
        final decision = ServiceDecision.bySlot[item.correctSlot];
        if (decision != null)
          await press('service-choice-${decision.correctIndex}');
        final actions = SimulationStepDetail.forItem(activity, item).actions;
        for (var i = 0; i < actions.length; i++) {
          if (activity.id == 'sim_coc2_ipconfig' && i == 1) {
            await tester.ensureVisible(
              find.byKey(const ValueKey('ipv4-address')),
            );
            await tester.enterText(
              find.byKey(const ValueKey('ipv4-address')),
              item.name.split(': ').last,
            );
            await tester.ensureVisible(find.byKey(const ValueKey('ipv4-mask')));
            await tester.enterText(
              find.byKey(const ValueKey('ipv4-mask')),
              '255.255.255.0',
            );
            tester.testTextInput.hide();
          }
          await press('perform-operation');
        }
        if (item.step.isEven) {
          await press('rework-operation');
          await press('perform-operation');
        }
        await press('accept-operation');
      }
      expect(result, (activity.items.length, activity.items.length, true));
      expect(find.text('Procedure complete'), findsOneWidget);
    });
  }
  test(
    'five migrated activities are quizzes with distinct class-scoped results',
    () {
      final quizzes = InteractiveQuizzes.forClass('c');
      expect(quizzes, hasLength(5));
      for (final quiz in quizzes) {
        final activity = InteractiveQuizzes.activity('c', quiz.id)!;
        expect(
          SimulationData.getAllSimulations().map((s) => s.id),
          isNot(contains(activity.id)),
        );
        expect(SimulationData.getSimulationById(activity.id), isNotNull);
        expect(InteractiveQuizzes.activity('other', quiz.id), isNull);
        expect(quiz.totalPoints, activity.items.length);
      }
      final unpublished = quizzes.first.copyWith(isPublished: false);
      final merged = InteractiveQuizzes.merge('c', [unpublished]);
      expect(merged, hasLength(5));
      expect(merged.first.isPublished, false);
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(620, 900),
  ]) {
    for (final activity in SimulationData.getQuizActivities()) {
      testWidgets('${activity.id} fits portrait $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Interactive quiz')),
              body: InteractiveQuizWorkbench(
                activity: activity,
                onComplete: (_, _, _) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('Turn your screen sideways'), findsNothing);
        if (activity.id == 'sim_coc2_ipconfig' ||
            activity.id == 'sim_coc2_diagnostics') {
          expect(find.byType(SimulationStepLab), findsOneWidget);
          final perform = find.byKey(const ValueKey('perform-operation'));
          await tester.ensureVisible(perform);
          await tester.tap(perform);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  for (final activity in SimulationData.getQuizActivities()) {
    test(
      '${activity.id} preserves module gates, old lesson links and teacher locks',
      () async {
        final db = FakeFirebaseFirestore();
        final root = db.collection('classes').doc('c');
        final quizId = InteractiveQuizzes.idFor('c', activity.id);
        await root.set({
          'status': 'active',
          'teacherId': 't',
          'enrolledStudentIds': ['s'],
        });
        await root.collection('modules').doc('m').set({'isPublished': true});
        await root
            .collection('learning_paths')
            .doc('simulation_${activity.id}')
            .set({'moduleId': 'm'});
        Future<void> open() => LearningPathService.requireQuizAvailable(
          'c',
          quizId,
          firestore: db,
          studentId: 's',
        );
        await expectLater(open(), throwsStateError);
        await db
            .collection('users')
            .doc('s')
            .collection('module_progress')
            .doc('c_m')
            .set({'completed': true});
        await open();
        final next = await LearningContinuationService.next(
          'c',
          moduleId: 'm',
          firestore: db,
        );
        expect(next.single.quiz?.id, quizId);
        await root.collection('quizzes').doc(quizId).set({
          'isPublished': false,
        });
        await expectLater(open(), throwsStateError);
        expect(
          await LearningContinuationService.next(
            'c',
            moduleId: 'm',
            firestore: db,
          ),
          isEmpty,
        );
        await root.collection('quizzes').doc(quizId).update({
          'isPublished': true,
        });
        await db.collection('content_locks').doc('lock').set({
          'classId': 'c',
          'contentType': 'simulation',
          'contentId': activity.id,
          'isLocked': true,
        });
        await expectLater(open(), throwsStateError);
        await db.collection('content_locks').doc('lock').update({
          'contentType': 'quiz',
          'contentId': quizId,
        });
        await expectLater(open(), throwsStateError);
      },
    );
  }
}
