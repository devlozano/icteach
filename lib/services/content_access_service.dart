import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContentAccessService {
  static String lockId(String classId, String type, String contentId) =>
      '${classId}_${type}_$contentId';
  static bool isLocked(
    Iterable<Map<String, dynamic>> locks,
    String type,
    String contentId,
  ) => locks.any(
    (lock) =>
        lock['isLocked'] == true &&
        (lock['contentType'] == type ||
            (type == 'quiz' && lock['contentType'] == 'practice')) &&
        (lock['contentId'] == contentId || lock['contentId'] == '*'),
  );
  static Future<bool> isClassStaff(
    String classId, {
    FirebaseFirestore? firestore,
    String? userId,
  }) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      throw StateError('Please sign in to access class content.');
    final db = firestore ?? FirebaseFirestore.instance;
    final profile = (await db.collection('users').doc(uid).get()).data();
    if (profile?['isActive'] == false) return false;
    final role = profile?['role'];
    if (role == 'admin') return true;
    if (role != 'teacher' && role != 'trainer') return false;
    final classroom = (await db.collection('classes').doc(classId).get())
        .data();
    return classroom?['teacherId'] == uid ||
        (role == 'trainer' &&
            ((classroom?['trainerIds'] as List?) ?? []).contains(uid)) ||
        ((classroom?['enrolledStudentIds'] as List?) ?? []).contains(uid);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> locks(String classId) =>
      FirebaseFirestore.instance
          .collection('content_locks')
          .where('classId', isEqualTo: classId)
          .snapshots();
}
