import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAchievement {
  const StudentAchievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
  });
  final String title;
  final String description;
  final String icon;
  final int current;
  final int target;
  bool get unlocked => current >= target;
  double get progress => target == 0 ? 1 : (current / target).clamp(0, 1);
}

class StudentAchievementService {
  StudentAchievementService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<List<StudentAchievement>> load(
    String studentId,
    String classId,
  ) async {
    final user = _firestore.collection('users').doc(studentId);
    final results = await Future.wait([
      user.collection('quiz_results').get(),
      user.collection('module_progress').get(),
      user.collection('simulation_progress').get(),
      _firestore
          .collection('pre_assessments')
          .doc('${studentId}_$classId')
          .get(),
    ]);
    final quizzes = (results[0] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((doc) => doc.data())
        .where((data) => data['classId'] == classId)
        .toList();
    final modules = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((doc) => doc.data())
        .where(
          (data) => data['classId'] == classId && data['completed'] == true,
        )
        .length;
    final simulations = (results[2] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((doc) => doc.data())
        .where(
          (data) =>
              data['classId'] == classId &&
              data['completed'] == true &&
              data['passed'] == true,
        )
        .length;
    final assessment = (results[3] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    return calculate(
      quizPercentages: quizzes.map(_percentage),
      completedModules: modules,
      passedSimulations: simulations,
      assessmentCompleted: assessment?['completed'] == true,
    );
  }

  static double _percentage(Map<String, dynamic> data) {
    final saved = data['percentage'];
    if (saved is num) return saved.toDouble();
    final score = data['score'];
    final total = data['totalPoints'];
    return score is num && total is num && total > 0 ? score / total * 100 : 0;
  }

  static List<StudentAchievement> calculate({
    required Iterable<double> quizPercentages,
    required int completedModules,
    required int passedSimulations,
    required bool assessmentCompleted,
  }) {
    final scores = quizPercentages.toList();
    return [
      StudentAchievement(
        title: 'Ready to Learn',
        description: 'Complete the pre-assessment',
        icon: '🧭',
        current: assessmentCompleted ? 1 : 0,
        target: 1,
      ),
      StudentAchievement(
        title: 'First Quiz',
        description: 'Complete your first quiz',
        icon: '🏆',
        current: scores.length,
        target: 1,
      ),
      StudentAchievement(
        title: 'Module Master',
        description: 'Complete 3 modules',
        icon: '⭐',
        current: completedModules,
        target: 3,
      ),
      StudentAchievement(
        title: 'Module Starter',
        description: 'Complete your first module',
        icon: 'book',
        current: completedModules,
        target: 1,
      ),
      StudentAchievement(
        title: 'Learning Champion',
        description: 'Complete 5 modules',
        icon: 'crown',
        current: completedModules,
        target: 5,
      ),
      StudentAchievement(
        title: 'Quiz Explorer',
        description: 'Complete 3 quizzes',
        icon: 'quiz_streak',
        current: scores.length,
        target: 3,
      ),
      StudentAchievement(
        title: 'High Achiever',
        description: 'Earn at least 90% on a quiz',
        icon: 'medal',
        current: scores.any((score) => score >= 90) ? 1 : 0,
        target: 1,
      ),
      StudentAchievement(
        title: 'Perfect Score',
        description: 'Earn 100% on a quiz',
        icon: '🎯',
        current: scores.any((score) => score >= 99.999) ? 1 : 0,
        target: 1,
      ),
      StudentAchievement(
        title: 'Tech Explorer',
        description: 'Pass 2 simulations',
        icon: '🔧',
        current: passedSimulations,
        target: 2,
      ),
      StudentAchievement(
        title: 'Simulation Rookie',
        description: 'Pass your first simulation',
        icon: 'wrench',
        current: passedSimulations,
        target: 1,
      ),
      StudentAchievement(
        title: 'Simulation Specialist',
        description: 'Pass 5 simulations',
        icon: 'shield',
        current: passedSimulations,
        target: 5,
      ),
    ];
  }
}
