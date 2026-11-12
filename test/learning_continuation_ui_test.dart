import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/quiz_model.dart';
import 'package:icteach/screens/student/quiz_results_page.dart';

void main() {
  testWidgets(
    'results offer simulation continuation and Done returns one route',
    (tester) async {
      final result = QuizResult(
        quizId: 'quiz',
        classId: 'class',
        studentId: 'student',
        studentName: 'Student',
        score: 1,
        totalPoints: 1,
        completedAt: DateTime(2026),
        timeSpent: 10,
        userAnswers: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizResultsPage(
                                result: result,
                                questions: [],
                                quizTitle: 'Quiz',
                              ),
                            ),
                          ),
                          child: const Text('Show results'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open quiz'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open quiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(find.text('Continue to Simulation'), findsOneWidget);
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Show results'), findsOneWidget);
      expect(find.text('Open quiz'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
