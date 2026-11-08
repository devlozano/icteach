import 'dart:io';
import 'dart:ui' as ui;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/screens/teacher/progress_tracker_page.dart';
import 'package:icteach/services/css_gradebook_service.dart';
import 'package:icteach/utils/deped_grading.dart';

const preview = bool.fromEnvironment('INSIGHTS_PREVIEW');

void main() {
  setUpAll(() async {
    if (preview) {
      final bytes = await File(
        const String.fromEnvironment('INSIGHTS_FONT'),
      ).readAsBytes();
      await (FontLoader(
        'PreviewFont',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      final icons = await File(
        const String.fromEnvironment('INSIGHTS_ICONS'),
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    }
  });

  for (final width in [320.0, 360.0, 1280.0]) {
    testWidgets('All five insights tabs render and filter at $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      await db.collection('classes').doc('class').set({
        'enrolledStudentIds': ['a', 'b'],
        'teacherId': 'teacher',
      });
      await db.collection('users').doc('a').set({
        'name': 'Alexandra Dela Cruz',
        'role': 'student',
      });
      await db.collection('users').doc('b').set({
        'name': 'Miguel Santos',
        'role': 'student',
      });
      await db.collection('quiz_results').add({
        'classId': 'class',
        'studentId': 'a',
        'percentage': 85,
      });
      await db
          .collection('users')
          .doc('a')
          .collection('simulation_progress')
          .add({
            'classId': 'class',
            'simulationTitle': 'Computer assembly and cable management',
            'percentage': 92,
            'passed': true,
            'attempts': 2,
          });
      await db.collection('activity_feedback').add({
        'classId': 'class',
        'simulationTitle': 'Computer assembly',
        'difficulty': 'Moderate',
        'comment':
            'The wiring activity helped me understand where each cable connects.',
      });
      await db.collection('questionnaire_responses').add({
        'classId': 'class',
        'questionnaireTitle': 'Lesson reflection',
        'studentName': 'Alexandra Dela Cruz',
        'summary': 'The practical examples were helpful.',
        'ratings': {'clarity': 4},
        'ratingPrompts': {
          'clarity': 'The lesson instructions were clear and easy to follow.',
        },
      });
      final service = CssGradebookService(
        'class',
        firestore: db,
        teacherId: 'teacher',
      );
      await service.configure(CssGradingProfile.techPro, 2026);
      await service.save('a', 1, {
        for (final c in DepEdGrading.components) c: GradeScore(80, 100),
      });
      final repaint = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaint,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.5 : 1)),
              child: child!,
            ),
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: preview ? 'PreviewFont' : null,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF087F8C),
              ),
            ),
            home: ProgressTrackerPage(
              classId: 'class',
              className: 'Grade 11 • Computer Systems Servicing',
              firestore: db,
              gradebookService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String tab) async {
        expect(tester.takeException(), isNull, reason: '$tab at $width');
        if (!preview) return;
        final boundary =
            repaint.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('.tmp/insights-ui');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/${width.toInt()}-$tab.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('overview');
      final headings = {
        'Students': 'Student progress',
        'Simulations': 'Practical learning',
        'Feedback': 'Listen to your learners',
        'Grades': 'CSS gradebook',
      };
      for (final item in headings.entries) {
        final tab = find.widgetWithText(Tab, item.key);
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.text(item.value), findsOneWidget);
        await capture(item.key.toLowerCase());
        if (item.key == 'Students') {
          final studentScroll = find
              .descendant(
                of: find.byKey(const ValueKey('insights-students')),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.enterText(find.byType(TextField), 'Miguel');
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('1 of 2 students'),
            200,
            scrollable: studentScroll,
          );
          expect(find.text('1 of 2 students'), findsOneWidget);
          expect(find.text('Alexandra Dela Cruz'), findsNothing);
          await tester.scrollUntilVisible(
            find.byType(TextField),
            -200,
            scrollable: studentScroll,
          );
          await tester.enterText(find.byType(TextField), '');
          await tester.ensureVisible(find.text('No activity').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('No activity').first);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('1 of 2 students'),
            200,
            scrollable: studentScroll,
          );
          expect(find.text('1 of 2 students'), findsOneWidget);
        }
        if (item.key == 'Feedback') {
          await tester.scrollUntilVisible(
            find.text('Lesson reflection'),
            250,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('insights-feedback')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Lesson reflection'));
          await tester.pumpAndSettle();
          expect(find.text('4/5'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        if (item.key == 'Grades') {
          await tester.scrollUntilVisible(
            find.text('Alexandra Dela Cruz'),
            250,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('insights-grades')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Alexandra Dela Cruz'));
          await tester.pumpAndSettle();
          expect(find.text('Record component scores'), findsOneWidget);
          await capture('score-entry');
        }
      }
    });
  }
}
