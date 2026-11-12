import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/simulation_data.dart';
import '../models/quiz_model.dart';

class LearningDestination {
  final String id, title;
  final QuizModel? quiz;
  const LearningDestination(this.id, this.title, {this.quiz});
}

class LearningContinuationService {
  static Future<List<LearningDestination>> next(
    String classId, {
    String? moduleId,
    String? quizId,
    FirebaseFirestore? firestore,
  }) async {
    final root = (firestore ?? FirebaseFirestore.instance)
        .collection('classes')
        .doc(classId);
    final paths = await root
        .collection('learning_paths')
        .where(
          quizId == null ? 'moduleId' : 'quizId',
          isEqualTo: quizId ?? moduleId,
        )
        .get();
    final destinations = <LearningDestination>[];
    if (quizId == null) {
      for (final path in paths.docs.where((p) => p.id.startsWith('quiz_'))) {
        final id = path.id.substring(5);
        final doc = await root.collection('quizzes').doc(id).get();
        if (!doc.exists || doc.data()?['isPublished'] != true) continue;
        final quiz = QuizModel.fromFirestore(doc);
        if (quiz.questions.isNotEmpty)
          destinations.add(LearningDestination(id, quiz.title, quiz: quiz));
      }
    } else {
      final linked = paths.docs
          .where((p) => p.id.startsWith('simulation_'))
          .map((p) => p.id.substring(11))
          .toSet();
      for (final simulation in SimulationData.getAllSimulations()) {
        if (linked.contains(simulation.id)) {
          destinations.add(
            LearningDestination(simulation.id, simulation.title),
          );
        }
      }
    }
    destinations.sort((a, b) => a.title.compareTo(b.title));
    return destinations;
  }
}
