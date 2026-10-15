import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/quiz_model.dart';

void main() {
  test('student quiz result stores selections and score, never the answer key', () {
    final result = QuizResult(
      quizId: 'quiz',
      classId: 'class',
      studentId: 'student',
      studentName: 'Student',
      score: 1,
      totalPoints: 2,
      completedAt: DateTime(2026),
      timeSpent: 30,
      userAnswers: [
        UserAnswer(
          questionId: 'question',
          selectedAnswer: 1,
          isCorrect: true,
          correctAnswerText: 'Private answer key',
          explanation: 'Private explanation',
        ),
      ],
    );

    final answer = (result.toFirestore()['userAnswers'] as List).single as Map;
    expect(answer, {'questionId': 'question', 'selectedAnswer': 1});
  });
}
