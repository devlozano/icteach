import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Practice records deliberately never enter quiz_results or simulation_progress.
class LearningPathService {
  static String key(String type, String id) => '${type}_$id';
  static Future<void> requirePrepared(
    String classId,
    String type,
    String id, {
    required bool practice,
  }) async {
    if (type == 'quiz') {
      if (practice) throw StateError('Quizzes only support scored attempts.');
      await requireQuizAvailable(classId, id);
      return;
    }
    await requireActive(classId);
    final db = FirebaseFirestore.instance;
    final user = db
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid);
    final root = db.collection('classes').doc(classId);
    final path =
        (await root.collection('learning_paths').doc(key(type, id)).get())
            .data();
    if (path?['moduleId'] == null)
      throw StateError('A linked lesson is required.');
    final module =
        (await root.collection('modules').doc(path!['moduleId']).get()).data();
    final progress =
        (await user
                .collection('module_progress')
                .doc('${classId}_${path['moduleId']}')
                .get())
            .data();
    if (module?['isPublished'] != true || progress?['completed'] != true)
      throw StateError('Complete the published lesson first.');
    final locks = await db
        .collection('content_locks')
        .where('classId', isEqualTo: classId)
        .get();
    for (final doc in locks.docs) {
      final lock = doc.data();
      final kind = lock['contentType'];
      final target = lock['contentId'];
      if (lock['isLocked'] == true &&
          (((kind == type || (type == 'quiz' && kind == 'practice')) &&
                  (target == id || target == '*')) ||
              (kind == 'module' &&
                  (target == path['moduleId'] || target == '*')))) {
        throw StateError(
          'Your teacher/trainer has locked this learning activity.',
        );
      }
    }
    if (practice) return;
    final rehearsal =
        (await user
                .collection('practice_progress')
                .doc('${classId}_${key(type, id)}')
                .get())
            .data();
    if (rehearsal?['completed'] != true)
      throw StateError('Complete ungraded practice first.');
    if (type == 'simulation') {
      if (path['quizId'] == null)
        throw StateError('A linked theory quiz is required.');
      final quiz = (await root.collection('quizzes').doc(path['quizId']).get())
          .data();
      final theory =
          (await user.collection('quiz_results').doc(path['quizId']).get())
              .data();
      if (quiz?['isPublished'] != true || theory?['classId'] != classId)
        throw StateError('Complete the published theory quiz first.');
    }
  }

  /// Published quizzes do not depend on simulation lesson/practice setup.
  static Future<void> requireQuizAvailable(
    String classId,
    String quizId, {
    FirebaseFirestore? firestore,
    String? studentId,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    await requireActive(classId, firestore: db, userId: studentId);
    final quiz =
        (await db
                .collection('classes')
                .doc(classId)
                .collection('quizzes')
                .doc(quizId)
                .get())
            .data();
    if (quiz?['isPublished'] != true) {
      throw StateError(
        'This quiz is not published. Ask your teacher to publish it.',
      );
    }
    if ((quiz?['questions'] as List? ?? []).isEmpty) {
      throw StateError(
        'This quiz has no questions yet. Ask your teacher to add questions.',
      );
    }
    final locks = await db
        .collection('content_locks')
        .where('classId', isEqualTo: classId)
        .get();
    for (final doc in locks.docs) {
      final lock = doc.data();
      if (lock['isLocked'] == true &&
          (lock['contentType'] == 'quiz' ||
              lock['contentType'] == 'practice') &&
          (lock['contentId'] == quizId || lock['contentId'] == '*')) {
        throw StateError('Your teacher/trainer has locked this quiz.');
      }
    }
  }

  static Future<void> requireActive(
    String classId, {
    FirebaseFirestore? firestore,
    String? userId,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final data = (await db.collection('classes').doc(classId).get()).data();
    if (data == null || data['status'] == 'archived') {
      throw StateError(
        'This class is archived or unavailable. Previous records are preserved.',
      );
    }
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    if (data['teacherId'] != uid &&
        !(data['enrolledStudentIds'] as List? ?? []).contains(uid)) {
      final role = (await db.collection('users').doc(uid).get())
          .data()?['role'];
      if (role != 'admin')
        throw StateError('Join this class before accessing its activities.');
    }
  }

  static Future<void> savePractice(
    String classId,
    String type,
    String id,
    String title,
    int score,
    int total,
  ) async {
    await requirePrepared(classId, type, id, practice: true);
    final user = FirebaseAuth.instance.currentUser!;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final data = <String, dynamic>{
      'classId': classId,
      'studentId': user.uid,
      'contentType': type,
      'contentId': id,
      'title': title,
      'mode': 'practice',
      'completed': true,
      'score': score,
      'total': total,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(
      db
          .collection('users')
          .doc(user.uid)
          .collection('practice_progress')
          .doc('${classId}_${key(type, id)}'),
      data,
    );
    batch.set(db.collection('activity_events').doc(), {
      ...data,
      'studentName': user.displayName ?? user.email ?? 'Student',
      'event': 'practice_completed',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
