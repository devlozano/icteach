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

    final results = await Future.wait([
      records('quiz_results'),
      records('module_progress', nested: true),
      records('simulation_progress', nested: true),
      records('pre_assessments'),
    ]);
    final quizzes = results[0],
        modules = results[1],
        simulations = results[2],
        pre = results[3];
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
    final data = await Future.wait([
      db.collection('users').where('role', isEqualTo: 'student').get(),
      db.collection('classes').get(),
      db.collection('quiz_results').get(),
    ]);
    final students = data[0].docs,
        classes = data[1].docs,
        quizzes = data[2].docs;
    final ids = students.map((s) => s.id).toSet();
    final moduleRows = <List<Object?>>[];
    for (var offset = 0; offset < classes.length; offset += 10) {
      final batch = classes.skip(offset).take(10).toList();
      final content = await Future.wait(
        batch.map((c) => c.reference.collection('modules').get()),
      );
      for (var i = 0; i < batch.length; i++) {
        final modules = content[i].docs;
        moduleRows.add([
          batch[i].data()['name'] ?? batch[i].id,
          modules.length,
          modules.where((m) => m.data()['isPublished'] == true).length,
        ]);
      }
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
