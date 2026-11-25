import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/css_gradebook_service.dart';
import '../teacher/css_gradebook_page.dart';

class TrainerGradebookPage extends StatelessWidget {
  const TrainerGradebookPage({
    super.key,
    required this.classId,
    required this.className,
    this.firestore,
    this.trainerId,
  });

  final String classId;
  final String className;
  final FirebaseFirestore? firestore;
  final String? trainerId;

  @override
  Widget build(BuildContext context) {
    final db = firestore ?? FirebaseFirestore.instance;
    final ownerId = trainerId ?? FirebaseAuth.instance.currentUser!.uid;
    final service = CssGradebookService.trainer(
      classId,
      firestore: db,
      trainerId: ownerId,
    );
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('classes').doc(classId).snapshots(),
      builder: (context, classSnapshot) {
        if (classSnapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to load this assigned class.')),
          );
        }
        if (!classSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final classData = classSnapshot.data!.data() ?? const {};
        final studentIds = List<String>.from(
          classData['enrolledStudentIds'] as List? ?? const [],
        );
        if (studentIds.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('$className grades')),
            body: const Center(child: Text('No enrolled students yet.')),
          );
        }
        return FutureBuilder<Map<String, String>>(
          future: _loadStudents(db, studentIds),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('Unable to load the class roster.')),
              );
            }
            if (!studentsSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return Scaffold(
              backgroundColor: const Color(0xFFF4F7FB),
              appBar: AppBar(
                backgroundColor: const Color(0xFF0B2B4A),
                foregroundColor: Colors.white,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trainer gradebook',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              body: CssGradebookPage(
                classId: classId,
                students: studentsSnapshot.data!,
                service: service,
                ownerLabel: 'Trainer',
              ),
            );
          },
        );
      },
    );
  }

  static Future<Map<String, String>> _loadStudents(
    FirebaseFirestore db,
    List<String> studentIds,
  ) async {
    final students = <String, String>{};
    for (var start = 0; start < studentIds.length; start += 30) {
      final end = (start + 30).clamp(0, studentIds.length);
      final snapshot = await db
          .collection('users')
          .where(FieldPath.documentId, whereIn: studentIds.sublist(start, end))
          .get();
      for (final student in snapshot.docs) {
        if (student.data()['role'] == 'student') {
          students[student.id] = _studentName(student.data());
        }
      }
    }
    return students;
  }

  static String _studentName(Map<String, dynamic> data) {
    final direct = data['name']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final parts =
        [
              data['firstName'],
              data['middleName'],
              data['surname'] ?? data['lastName'],
              data['extension'],
            ]
            .map((part) => part?.toString().trim() ?? '')
            .where((part) => part.isNotEmpty);
    final name = parts.join(' ');
    return name.isNotEmpty ? name : data['email']?.toString() ?? 'Student';
  }
}
