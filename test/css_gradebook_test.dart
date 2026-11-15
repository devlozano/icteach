import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/css_gradebook_service.dart';
import 'package:icteach/screens/teacher/css_gradebook_page.dart';
import 'package:icteach/utils/deped_grading.dart';

void main() {
  test('teacher gradebook remains in the authoritative teacher path', () {
    final service = CssGradebookService(
      'class-a',
      firestore: FakeFirebaseFirestore(),
      teacherId: 'teacher-a',
    );
    expect(service.book.path, 'css_gradebooks/teacher-a/classes/class-a');
  });

  test(
    'Save, reload, and isolate three terms; setup cannot reinterpret saved grades',
    () async {
      final service = CssGradebookService(
        'class',
        firestore: FakeFirebaseFirestore(),
        teacherId: 'teacher',
      );
      await service.configure(CssGradingProfile.techPro, 2026);
      final scores = {
        for (final c in DepEdGrading.components) c: GradeScore(70, 100),
      };
      await service.save('student', 1, scores);
      await service.save('student', 2, {});
      final saved = await service.book
          .collection('records')
          .doc('student_1')
          .get();
      expect(
        DepEdGrading.calculate(
          CssGradebookService.readScores(saved.data()!),
          CssGradingProfile.techPro,
          2026,
        )!.grade,
        75,
      );
      expect((await service.book.collection('records').get()).docs.length, 2);
      await expectLater(
        service.configure(CssGradingProfile.tle, 2027),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'Mobile gradebook displays workbook periods and complete overall grade',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CssGradebookService(
        'class',
        firestore: FakeFirebaseFirestore(),
        teacherId: 'teacher',
      );
      await service.configure(CssGradingProfile.techPro, 2026);
      for (var term = 1; term <= 3; term++) {
        await service.save('student', term, {
          for (final c in DepEdGrading.components) c: GradeScore(70, 100),
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CssGradebookPage(
              classId: 'class',
              students: const {'student': 'Sample Student'},
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sample Student'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Prelim'), findsWidgets);
      expect(find.text('Midterm'), findsWidgets);
      expect(find.text('Final'), findsWidgets);
      expect(find.text('Overall'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Edit Prelim').first,
        300,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.right,
            )
            .last,
      );
      await tester.ensureVisible(find.text('Edit Prelim').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Prelim').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '60');
      await tester.scrollUntilVisible(
        find.text('Save scores'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Prelim grade: 74'), findsOneWidget);
      await tester.tap(find.text('Save scores'));
      await tester.pumpAndSettle();
      expect(find.text('74'), findsOneWidget);
      final saved = await service.book
          .collection('records')
          .doc('student_1')
          .get();
      expect(CssGradebookService.readScores(saved.data()!)['quiz']!.raw, 60);
      expect(tester.takeException(), isNull);
    },
  );
}
