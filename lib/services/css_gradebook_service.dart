import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/deped_grading.dart';

class CssGradebookService {
  CssGradebookService(
    String classId, {
    FirebaseFirestore? firestore,
    String? teacherId,
    String collection = 'css_gradebooks',
  }) : book = (firestore ?? FirebaseFirestore.instance)
           .collection(collection)
           .doc(teacherId ?? FirebaseAuth.instance.currentUser!.uid)
           .collection('classes')
           .doc(classId);
  factory CssGradebookService.trainer(
    String classId, {
    FirebaseFirestore? firestore,
    String? trainerId,
  }) => CssGradebookService(
    classId,
    firestore: firestore,
    teacherId: trainerId,
    collection: 'trainer_gradebooks',
  );
  final DocumentReference<Map<String, dynamic>> book;

  Future<void> configure(CssGradingProfile profile, int year) async {
    await book.firestore.runTransaction((transaction) async {
      final existing = await transaction.get(book);
      if (existing.exists) {
        throw StateError('Grading profile is already configured.');
      }
      transaction.set(book, {
        'profile': profile.name,
        'year': year,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> save(
    String studentId,
    int term,
    Map<String, GradeScore> scores,
  ) {
    if (term < 1 || term > 3) throw ArgumentError('Term must be 1, 2 or 3.');
    return book.collection('records').doc('${studentId}_$term').set({
      'studentId': studentId,
      'term': term,
      'scores': scores.map((key, value) => MapEntry(key, value.toMap())),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Map<String, GradeScore> readScores(Map<String, dynamic> record) =>
      Map<String, dynamic>.from(record['scores'] as Map? ?? {}).map(
        (key, value) => MapEntry(
          key,
          GradeScore.fromMap(Map<String, dynamic>.from(value as Map)),
        ),
      );
}
