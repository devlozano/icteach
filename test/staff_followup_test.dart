import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/pre_assessment_data.dart';
import 'package:icteach/services/assessment_order.dart';
import 'package:icteach/services/module_access_service.dart';
import 'package:icteach/services/summary_pdf_service.dart';
import 'package:icteach/services/workspace_navigation.dart';
import 'package:icteach/widgets/persistent_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'randomized questions and choices preserve original pre-assessment scoring',
    () {
      final questions = PreAssessmentData.questions;
      final originalPrompts = questions.map((q) => q.prompt).toList();
      final orders = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final order = AssessmentOrder(
          questions.map((q) => q.options.length).toList(),
          random: Random(seed),
        );
        expect(order.questions.toSet().length, questions.length);
        final answers = List<int>.filled(questions.length, -1);
        for (final i in order.questions) {
          expect(
            order.options[i].toSet(),
            Set.of(List.generate(questions[i].options.length, (n) => n)),
          );
          final displayedCorrectPosition = order.options[i].indexOf(
            questions[i].answer,
          );
          answers[i] = order.options[i][displayedCorrectPosition];
        }
        expect(PreAssessmentData.score(answers)['score'], questions.length);
        orders.add(order.questions.join(','));
      }
      expect(orders.length, greaterThan(1));
      expect(questions.map((q) => q.prompt).toList(), originalPrompts);
    },
  );
  test(
    'module counters deduplicate enrolled students and never count a request as saved',
    () {
      final summary = ModuleAccessSummary.fromRecords(
        [
          {'studentId': 'a', 'accessed': true, 'downloadRequested': true},
          {'studentId': 'a', 'accessed': true, 'downloadRequested': true},
          {
            'studentId': 'b',
            'accessed': true,
            'downloadRequested': true,
            'downloaded': true,
          },
          {'studentId': 'staff', 'accessed': true, 'downloaded': true},
        ],
        {'a', 'b', 'c'},
      );
      expect(summary.accessed, 2);
      expect(summary.downloaded, 1);
      expect(summary.requested, 2);
    },
  );
  testWidgets(
    'logout dialog does not add a sidebar and clear removes detail navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [WorkspaceNavigation.instance],
          builder: (_, child) => PersistentWorkspace(child: child!),
          home: Builder(
            builder: (context) {
              PersistentWorkspace.register(
                context,
                const SizedBox(
                  width: 256,
                  child: Material(child: Text('External sidebar')),
                ),
              );
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text('Logout confirmation'),
                        ),
                      ),
                      child: const Text('Logout'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const Scaffold(body: Text('Detail')),
                        ),
                      ),
                      child: const Text('Open detail'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final width = tester.getSize(find.byType(Scaffold)).width;
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(find.text('External sidebar'), findsNothing);
      expect(tester.getSize(find.byType(Scaffold)).width, width);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('External sidebar'), findsOneWidget);
      PersistentWorkspace.clear();
      await tester.pumpAndSettle();
      expect(find.text('External sidebar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'college summary generates a multipage PDF with long names and comments',
    () async {
      final bytes = await SummaryPdfService.build(
        college: 'Sample College - PRINT LAYOUT TEST',
        title: 'Module and Student Summary',
        generatedAt: DateTime(2026, 9, 10),
        sections: [
          SummarySection(
            'Module access',
            ['Student', 'Access', 'Download'],
            [
              for (var i = 0; i < 180; i++)
                [
                  'Student $i - María Dela Peña',
                  'Accessed',
                  i.isEven ? 'Downloaded' : 'Not downloaded',
                ],
            ],
          ),
          SummarySection(
            'Feedback',
            ['Comment'],
            [
              [
                List.filled(
                  35,
                  'The learning materials help students prepare and practise.',
                ).join(' '),
              ],
            ],
          ),
        ],
      );
      expect(bytes.length, greaterThan(10000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      final file = File('build/print-qa/college-summary.pdf');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    },
  );
}
