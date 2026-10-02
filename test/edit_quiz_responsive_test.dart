import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/quiz_model.dart';
import 'package:icteach/screens/teacher/create_quiz_page.dart';

void main() {
  final quiz = QuizModel(
    id: 'quiz-1',
    classId: 'class-1',
    title: 'Responsive Quiz',
    description: 'A quiz used to verify the shared teacher and trainer editor.',
    questions: [
      Question(
        id: 'question-1',
        text: 'Which troubleshooting step should be completed first?',
        options: const [
          'Inspect the reported symptoms and document them',
          'Replace every component immediately',
          'Ignore the issue',
          'Restart without checking anything',
        ],
        correctAnswer: 0,
        explanation: 'Document the symptoms before changing the system.',
      ),
    ],
    timeLimit: 30,
    totalPoints: 1,
    passingScore: 1,
    isPublished: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(740, 360),
    const Size(1440, 900),
  ]) {
    testWidgets('Edit Quiz has no overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.2),
            ),
            child: CreateQuizPage(
              classId: 'class-1',
              className:
                  'Computer Systems Servicing NC II - Responsive Training Class',
              quizToEdit: quiz,
            ),
          ),
        ),
      );

      expect(find.text('Edit Quiz'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
