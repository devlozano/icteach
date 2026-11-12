import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/services/learning_continuation_service.dart';

void main() {
  test(
    'lesson continues only to its published, nonempty linked quizzes',
    () async {
      final db = FakeFirebaseFirestore();
      final root = db.collection('classes').doc('class');
      for (final id in ['ready', 'draft', 'empty', 'other']) {
        await root.collection('learning_paths').doc('quiz_$id').set({
          'moduleId': id == 'other' ? 'other-lesson' : 'lesson',
        });
        await root.collection('quizzes').doc(id).set({
          'title': id,
          'isPublished': id != 'draft',
          'questions': id == 'empty'
              ? []
              : [
                  {
                    'question': 'Q',
                    'options': ['A', 'B'],
                    'correctAnswer': 0,
                    'points': 1,
                  },
                ],
        });
      }
      await root.collection('learning_paths').doc('quiz_missing').set({
        'moduleId': 'lesson',
      });
      final items = await LearningContinuationService.next(
        'class',
        moduleId: 'lesson',
        firestore: db,
      );
      expect(items.map((i) => i.id), ['ready']);
      expect(items.single.quiz, isNotNull);
    },
  );

  test(
    'quiz continues only to linked active simulations in the same class',
    () async {
      final db = FakeFirebaseFirestore();
      final active = SimulationData.getAllSimulations().first;
      final root = db.collection('classes').doc('class');
      await root
          .collection('learning_paths')
          .doc('simulation_${active.id}')
          .set({'quizId': 'quiz'});
      await root.collection('learning_paths').doc('simulation_unknown').set({
        'quizId': 'quiz',
      });
      for (final retired in SimulationData.retiredSimulationIds) {
        await root.collection('learning_paths').doc('simulation_$retired').set({
          'quizId': 'quiz',
        });
      }
      final items = await LearningContinuationService.next(
        'class',
        quizId: 'quiz',
        firestore: db,
      );
      expect(items.map((i) => i.id), [active.id]);
      expect(items.single.quiz, isNull);
      expect(
        await LearningContinuationService.next(
          'other-class',
          quizId: 'quiz',
          firestore: db,
        ),
        isEmpty,
      );
      expect(
        await LearningContinuationService.next(
          'class',
          quizId: 'unlinked',
          firestore: db,
        ),
        isEmpty,
      );
    },
  );
}
