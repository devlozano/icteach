import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const helpfulnessPrompts = [
  'ICTeach helps me understand my lessons.',
  'The simulations help me practise real tasks.',
  'ICTeach helps me prepare for the NC II assessment.',
  'Overall, ICTeach helps me learn better.',
];

class RatingSummary {
  final List<int> counts = List.filled(5, 0);
  RatingSummary(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is num &&
          value.isFinite &&
          value == value.round() &&
          value >= 1 &&
          value <= 5) {
        counts[value.toInt() - 1]++;
      }
    }
  }
  int get total => counts.fold(0, (a, b) => a + b);
  double get average => total == 0
      ? 0
      : List.generate(5, (i) => counts[i] * (i + 1)).fold(0, (a, b) => a + b) /
            total;
}

class StudentOutcomes {
  static final db = FirebaseFirestore.instance;
  static Future<void> setPassed(
    String classId,
    String studentId,
    bool passed,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await db.runTransaction((tx) async {
      final classroom = await tx.get(db.collection('classes').doc(classId));
      final student = db.collection('users').doc(studentId);
      final profile = await tx.get(student);
      if (classroom.data()?['teacherId'] != uid ||
          !(List.from(
            classroom.data()?['enrolledStudentIds'] ?? [],
          ).contains(studentId)) ||
          profile.data()?['role'] != 'student') {
        throw StateError(
          'Only the assigned teacher can update an enrolled student.',
        );
      }
      tx.update(student, {
        'nc2Passed': passed,
        'nc2UpdatedBy': uid,
        'nc2ClassId': classId,
        'nc2UpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
