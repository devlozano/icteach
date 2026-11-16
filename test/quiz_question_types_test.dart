import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/quiz_model.dart';

void main() {
  test('old questions remain multiple choice', () {
    final question = Question.fromMap({
      'id': 'old',
      'text': 'Legacy item',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswer': 1,
      'points': 2,
    });
    expect(question.type, QuestionType.multipleChoice);
    expect(question.correctAnswer, 1);
  });

  test('all new question types survive storage', () {
    for (final type in QuestionType.values) {
      final original = Question(
        id: type.name,
        text: 'Question',
        options: type == QuestionType.trueFalse
            ? const ['True', 'False']
            : const ['A', 'B', 'C', 'D'],
        correctAnswer: 0,
        type: type,
        acceptedAnswers: const ['central processing unit', 'CPU'],
      );
      final restored = Question.fromMap(original.toMap());
      expect(restored.type, type);
      expect(restored.acceptedAnswers, original.acceptedAnswers);
    }
  });

  test(
    'typed answers ignore case and repeated spaces but reject wrong text',
    () {
      final question = Question(
        id: 'fill',
        text: 'CPU means _____.',
        options: const [],
        correctAnswer: 0,
        type: QuestionType.fillInTheBlank,
        acceptedAnswers: const ['Central Processing Unit', 'CPU'],
      );
      expect(question.matchesText('  central   processing UNIT '), isTrue);
      expect(question.matchesText('cpu'), isTrue);
      expect(question.matchesText('graphics processing unit'), isFalse);
    },
  );
}
