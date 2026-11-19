import '../models/quiz_model.dart';
import '../models/simulation_model.dart';
import 'simulation_data.dart';

/// Stable, class-scoped quiz IDs keep new marks separate from historical
/// simulation results and from another school year's class.
class InteractiveQuizzes {
  static String idFor(String classId, String activityId) =>
      'interactive_${classId}_$activityId';
  static Simulation? activity(String classId, String quizId) {
    for (final item in SimulationData.getQuizActivities()) {
      if (idFor(classId, item.id) == quizId) return item;
    }
    return null;
  }

  static List<QuizModel> forClass(String classId) => [
    for (final item in SimulationData.getQuizActivities())
      QuizModel(
        id: idFor(classId, item.id),
        classId: classId,
        title: item.title,
        description:
            '${item.description} Interactive procedure quiz in portrait layout.',
        questions: const [],
        timeLimit: 0,
        totalPoints: item.items.length,
        passingScore: (item.items.length * .8).ceil(),
        isPublished: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
  static List<QuizModel> merge(String classId, Iterable<QuizModel> saved) {
    final result = {for (final quiz in forClass(classId)) quiz.id: quiz};
    for (final quiz in saved) {
      final builtIn = result[quiz.id];
      result[quiz.id] = builtIn == null
          ? quiz
          : builtIn.copyWith(isPublished: quiz.isPublished);
    }
    return result.values.toList();
  }
}
