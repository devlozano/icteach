import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/utils/trainer_destinations.dart';
import 'package:icteach/screens/teacher/manage_modules_page.dart';
import 'package:icteach/screens/teacher/manage_quizzes_page.dart';
import 'package:icteach/screens/teacher/manage_assignments_page.dart';
import 'package:icteach/screens/teacher/progress_tracker_page.dart';
import 'package:icteach/screens/teacher/assessment_review_page.dart';
import 'package:icteach/screens/student/classmates_page.dart';

void main() {
  test(
    'trainer tool destinations preserve selected class and provide real screens',
    () {
      for (final action in ['modules', 'videos']) {
        final page =
            trainerDestination(action, 'selected-class', 'CSS')
                as ManageModulesPage;
        expect(page.classId, 'selected-class');
        expect(page.className, 'CSS');
      }
      expect(
        (trainerDestination('quizzes', 'c', 'CSS') as ManageQuizzesPage)
            .classId,
        'c',
      );
      expect(
        (trainerDestination('assignments', 'c', 'CSS') as ManageAssignmentsPage)
            .classId,
        'c',
      );
      expect(
        (trainerDestination('progress', 'c', 'CSS') as ProgressTrackerPage)
            .classId,
        'c',
      );
      expect(
        (trainerDestination('competency', 'c', 'CSS') as AssessmentReviewPage)
            .classId,
        'c',
      );
      expect(
        () => trainerDestination('invalid', 'c', 'CSS'),
        throwsArgumentError,
      );
    },
  );
  testWidgets('classmates shows names without editing or contact controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClassmatesPage(
          classId: 'c',
          className: 'CSS',
          loadNames: () async => ['Ana', 'Ben'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('classmates retry recovers after load failure', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ClassmatesPage(
          classId: 'c',
          className: 'CSS',
          loadNames: () async {
            calls++;
            if (calls == 1) throw StateError('offline');
            return ['Ana'];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('classmates empty state is explicit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClassmatesPage(
          classId: 'c',
          className: 'CSS',
          loadNames: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No classmates enrolled yet.'), findsOneWidget);
  });
}
