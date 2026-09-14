import 'package:cloud_firestore/cloud_firestore.dart';
import 'learning_path_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:icteach/services/notification_service.dart';
import '../models/quiz_model.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Get quizzes with offline support
  Stream<List<QuizModel>> getQuizzesForClass(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('quizzes')
        .snapshots(
          includeMetadataChanges: true,
        ) // ✅ Include metadata for offline
        .map((snapshot) {
          final quizzes = snapshot.docs
              .map((doc) => QuizModel.fromFirestore(doc))
              .toList();
          quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return quizzes;
        });
  }

  // ✅ Get published quizzes with offline support
  Stream<List<QuizModel>> getPublishedQuizzesForClass(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('quizzes')
        .where('isPublished', isEqualTo: true)
        .snapshots(
          includeMetadataChanges: true,
        ) // ✅ Include metadata for offline
        .map((snapshot) {
          final quizzes = snapshot.docs
              .map((doc) => QuizModel.fromFirestore(doc))
              .toList();
          quizzes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return quizzes;
        });
  }

  // Create a new quiz
  Future<void> createQuiz(QuizModel quiz) async {
    await LearningPathService.requireActive(quiz.classId);
    if (quiz.isPublished && quiz.questions.isEmpty)
      throw StateError('Add questions before publishing a quiz.');
    final docRef = _firestore
        .collection('classes')
        .doc(quiz.classId)
        .collection('quizzes')
        .doc();

    await docRef.set({...quiz.toFirestore(), 'id': docRef.id});
  }

  Future<void> updateQuiz(String classId, String quizId, QuizModel quiz) async {
    await LearningPathService.requireActive(classId);
    if (quiz.isPublished && quiz.questions.isEmpty)
      throw StateError('Add questions before publishing a quiz.');
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('quizzes')
          .doc(quizId)
          .update(quiz.toFirestore());
      print('✅ Quiz updated: ${quiz.title}');
    } catch (e) {
      print('❌ Error updating quiz: $e');
      rethrow;
    }
  }

  // Delete a quiz
  Future<void> deleteQuiz(String classId, String quizId) async {
    await LearningPathService.requireActive(classId);
    await _firestore
        .collection('classes')
        .doc(classId)
        .collection('quizzes')
        .doc(quizId)
        .delete();
  }

  // Get a single quiz by ID
  Future<QuizModel?> getQuiz(String classId, String quizId) async {
    final doc = await _firestore
        .collection('classes')
        .doc(classId)
        .collection('quizzes')
        .doc(quizId)
        .get();

    if (doc.exists) {
      return QuizModel.fromFirestore(doc);
    }
    return null;
  }

  // Toggle publish status
  Future<void> togglePublish(
    String classId,
    String quizId,
    bool isPublished,
  ) async {
    await LearningPathService.requireActive(classId);
    if (isPublished) {
      final quiz = await getQuiz(classId, quizId);
      if (quiz == null || quiz.questions.isEmpty) {
        throw StateError('Add questions before publishing a quiz.');
      }
    }
    await _firestore
        .collection('classes')
        .doc(classId)
        .collection('quizzes')
        .doc(quizId)
        .update({
          'isPublished': isPublished,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // Check if student has already taken a quiz
  Future<bool> hasTakenQuiz(String studentId, String quizId) async {
    try {
      if (studentId.isEmpty) {
        return false;
      }
      final doc = await _firestore
          .collection('users')
          .doc(studentId)
          .collection('quiz_results')
          .doc(quizId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking quiz status: $e');
      rethrow;
    }
  }

  // Save quiz result
  Future<void> saveQuizResult(QuizResult result) async {
    await LearningPathService.requirePrepared(
      result.classId,
      'quiz',
      result.quizId,
      practice: false,
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || result.studentId != user.uid) {
      throw StateError('Please sign in to save this result.');
    }
    final studentRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('quiz_results')
        .doc(result.quizId);
    final classRef = _firestore
        .collection('quiz_results')
        .doc('${result.quizId}_${user.uid}');
    await _firestore.runTransaction((transaction) async {
      final previous = await transaction.get(studentRef);
      final shared = await transaction.get(classRef);
      if (previous.exists || shared.exists) {
        throw StateError(
          'This quiz already has a saved result. Retakes are not allowed.',
        );
      }
      transaction.set(studentRef, result.toFirestore());
      transaction.set(classRef, result.toFirestore());
      transaction.set(_firestore.collection('activity_events').doc(), {
        'classId': result.classId,
        'studentId': result.studentId,
        'studentName': result.studentName,
        'contentId': result.quizId,
        'event': 'quiz_completed',
        'mode': 'assessment',
        'score': result.score,
        'total': result.totalPoints,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Get quiz results for a student globally
  Future<List<QuizResult>> getStudentQuizResults(String studentId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(studentId)
        .collection('quiz_results')
        .orderBy('completedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => QuizResult.fromFirestore(doc)).toList();
  }

  // Get quiz results for a student in a specific class
  Future<List<QuizResult>> getStudentQuizResultsForClass(
    String studentId,
    String classId,
  ) async {
    // 1. Get all quizzes for this class
    final quizzesSnapshot = await _firestore
        .collection('classes')
        .doc(classId)
        .collection('quizzes')
        .get();

    final quizIds = quizzesSnapshot.docs.map((doc) => doc.id).toList();

    if (quizIds.isEmpty) return [];

    // 2. Filter student's quiz results
    final snapshot = await _firestore
        .collection('users')
        .doc(studentId)
        .collection('quiz_results')
        .orderBy('completedAt', descending: true)
        .get();

    final allResults = snapshot.docs
        .map((doc) => QuizResult.fromFirestore(doc))
        .toList();

    return allResults
        .where((r) => quizIds.contains(r.quizId) || r.classId == classId)
        .toList();
  }

  // ✅ FIXED: Get quiz results without orderBy
  Future<List<QuizResult>> getQuizResults(String classId, String quizId) async {
    final snapshot = await _firestore
        .collection('quiz_results')
        .where('quizId', isEqualTo: quizId)
        .get();

    final results = snapshot.docs
        .map((doc) => QuizResult.fromFirestore(doc))
        .toList();

    // Sort in memory by score (descending)
    results.sort((a, b) => b.score.compareTo(a.score));

    return results;
  }

  // Get quiz attempt count
  Future<int> getQuizAttemptCount(String quizId) async {
    final snapshot = await _firestore
        .collection('quiz_results')
        .where('quizId', isEqualTo: quizId)
        .get();

    return snapshot.docs.length;
  }

  // Add notification method (if not exists)
  Future<void> notifyQuizPublished(String classId, String quizTitle) async {
    try {
      final notificationService = NotificationService();
      await notificationService.notifyNewQuiz(classId, quizTitle);
    } catch (e) {
      print('❌ Error sending quiz notification: $e');
    }
  }

  // ✅ NEW: Leaderboard Methods
  Future<List<Map<String, dynamic>>> getClassLeaderboard(String classId) async {
    try {
      // 1. Get all quizzes for this class
      final quizzesSnapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('quizzes')
          .get();

      final quizIds = quizzesSnapshot.docs.map((doc) => doc.id).toList();

      List<QueryDocumentSnapshot<Map<String, dynamic>>> allResultDocs = [];

      // 2. Fetch quiz_results matching these quizIds
      // Firestore 'whereIn' supports up to 10 elements, so chunk it
      for (var i = 0; i < quizIds.length; i += 10) {
        final end = (i + 10 < quizIds.length) ? i + 10 : quizIds.length;
        final chunk = quizIds.sublist(i, end);

        if (chunk.isNotEmpty) {
          final resultsSnapshot = await _firestore
              .collection('quiz_results')
              .where('quizId', whereIn: chunk)
              .get();

          allResultDocs.addAll(resultsSnapshot.docs);
        }
      }

      // Also fetch ones that have classId explicitly (for backwards compatibility)
      final explicitSnapshot = await _firestore
          .collection('quiz_results')
          .where('classId', isEqualTo: classId)
          .get();

      // Merge unique documents
      final uniqueDocs =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in allResultDocs) {
        uniqueDocs[doc.id] = doc;
      }
      for (final doc in explicitSnapshot.docs) {
        uniqueDocs[doc.id] = doc;
      }

      return _aggregateLeaderboardResults(uniqueDocs.values.toList());
    } catch (e) {
      print('Error getting class leaderboard: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalLeaderboard() async {
    final snapshot = await _firestore.collection('quiz_results').get();
    return _aggregateLeaderboardResults(snapshot.docs);
  }

  List<Map<String, dynamic>> _aggregateLeaderboardResults(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final studentAggregates = <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      final result = QuizResult.fromFirestore(doc);
      if (!studentAggregates.containsKey(result.studentId)) {
        studentAggregates[result.studentId] = {
          'studentId': result.studentId,
          'studentName': result.studentName,
          'totalScore': 0,
          'totalPoints': 0,
          'quizCount': 0,
        };
      }

      final data = studentAggregates[result.studentId]!;
      data['totalScore'] = (data['totalScore'] as int) + result.score;
      data['totalPoints'] = (data['totalPoints'] as int) + result.totalPoints;
      data['quizCount'] = (data['quizCount'] as int) + 1;
    }

    final leaderboard = studentAggregates.values.map((data) {
      final totalScore = data['totalScore'] as int;
      final totalPoints = data['totalPoints'] as int;
      final percentage = totalPoints > 0
          ? (totalScore / totalPoints) * 100
          : 0.0;

      return {...data, 'percentage': percentage.round()};
    }).toList();

    // Sort by percentage descending, then by total score
    leaderboard.sort((a, b) {
      final cmp = (b['percentage'] as int).compareTo(a['percentage'] as int);
      if (cmp != 0) return cmp;
      return (b['totalScore'] as int).compareTo(a['totalScore'] as int);
    });

    return leaderboard;
  }
}
