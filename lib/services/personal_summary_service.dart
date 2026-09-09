import 'package:cloud_firestore/cloud_firestore.dart';
import 'summary_pdf_service.dart';

class PersonalSummaryService {
  static Future<List<SummarySection>> load(
    String uid, {
    String? classId,
  }) async {
    final db = FirebaseFirestore.instance;
    final profile = (await db.collection('users').doc(uid).get()).data() ?? {};
    Future<List<Map<String, dynamic>>> records(
      String collection, {
      bool nested = false,
    }) async {
      Query<Map<String, dynamic>> query = nested
          ? db.collection('users').doc(uid).collection(collection)
          : db.collection(collection).where('studentId', isEqualTo: uid);
      final data = (await query.get()).docs.map((d) => d.data());
      return data
          .where((r) => classId == null || r['classId'] == classId)
          .toList();
    }

    final quizzes = await records('quiz_results');
    final modules = await records('module_progress', nested: true);
    final simulations = await records('simulation_progress', nested: true);
    final pre = await records('pre_assessments');
    return [
      SummarySection(
        'Student',
        ['Name', 'NC II'],
        [
          [
            profile['name'] ?? profile['email'],
            profile['nc2Passed'] == true ? 'Passed' : 'No recorded pass',
          ],
        ],
      ),
      SummarySection(
        'Modules',
        ['Module', 'Completed'],
        [
          for (final m in modules)
            [m['moduleId'], m['completed'] == true ? 'Yes' : 'No'],
        ],
      ),
      SummarySection(
        'Quizzes',
        ['Quiz', 'Score', 'Total'],
        [
          for (final q in quizzes)
            [q['quizTitle'] ?? q['quizId'], q['score'], q['totalPoints']],
        ],
      ),
      SummarySection(
        'Simulations',
        ['Simulation', 'Score', 'Passed'],
        [
          for (final s in simulations)
            [
              s['simulationTitle'] ?? s['simulationId'],
              s['score'],
              s['passed'],
            ],
        ],
      ),
      SummarySection(
        'Pre-assessment',
        ['Score', 'Total'],
        [
          for (final p in pre) [p['score'], p['totalQuestions']],
        ],
      ),
    ];
  }
}

class AdminSummaryService {
  static Future<List<SummarySection>> load() async {
    final db = FirebaseFirestore.instance;
    final students =
        (await db.collection('users').where('role', isEqualTo: 'student').get())
            .docs;
    final classes = (await db.collection('classes').get()).docs;
    final quizzes = (await db.collection('quiz_results').get()).docs;
    final ids = students.map((s) => s.id).toSet();
    final moduleRows = <List<Object?>>[];
    for (final c in classes) {
      final modules = (await c.reference.collection('modules').get()).docs;
      moduleRows.add([
        c.data()['name'] ?? c.id,
        modules.length,
        modules.where((m) => m.data()['isPublished'] == true).length,
      ]);
    }
    return [
      SummarySection(
        'Students',
        ['Students', 'NC II passed', 'No recorded pass'],
        [
          [
            students.length,
            students.where((s) => s.data()['nc2Passed'] == true).length,
            students.where((s) => s.data()['nc2Passed'] != true).length,
          ],
        ],
      ),
      SummarySection(
        'Class enrollment',
        ['Class', 'Students'],
        [
          for (final c in classes)
            [
              c.data()['name'] ?? c.id,
              Set<String>.from(
                c.data()['enrolledStudentIds'] ?? [],
              ).intersection(ids).length,
            ],
        ],
      ),
      SummarySection('Module publishing', [
        'Class',
        'Modules',
        'Published',
      ], moduleRows),
      SummarySection(
        'Quiz performance',
        ['Student', 'Quiz', 'Score', 'Total'],
        [
          for (final q in quizzes.where(
            (q) => ids.contains(q.data()['studentId']),
          ))
            [
              q.data()['studentName'],
              q.data()['quizTitle'] ?? q.data()['quizId'],
              q.data()['score'],
              q.data()['totalPoints'],
            ],
        ],
      ),
    ];
  }
}
