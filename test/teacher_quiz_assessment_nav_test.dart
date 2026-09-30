import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/teacher_home.dart';
import 'package:icteach/widgets/staff_mobile_nav.dart';

void main() {
  testWidgets(
    'teacher quiz and assessment hub fits a phone and exposes both flows',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TeacherQuizAssessmentHub())),
      );

      expect(find.text('Manage Quizzes'), findsOneWidget);
      expect(find.text('Manage Assessments'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('teacher mobile More menu includes Quiz & Assessment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StaffMobileNav(
            currentIndex: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz & Assessment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
