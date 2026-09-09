import 'package:cloud_firestore/cloud_firestore.dart';
import 'summary_pdf_service.dart';
import 'module_access_service.dart';

class ClassSummaryService {
  static Future<List<SummarySection>> load(String classId) async {
    final db = FirebaseFirestore.instance;
    final classroom =
        (await db.collection('classes').doc(classId).get()).data() ?? {};
    final members = Set<String>.from(classroom['enrolledStudentIds'] ?? []);
    final profiles = await Future.wait(
      members.map((id) => db.collection('users').doc(id).get()),
    );
    final students = profiles
        .where((p) => p.data()?['role'] == 'student')
        .toList();
    final ids = students.map((p) => p.id).toSet();
    final names = {
      for (final p in students)
        p.id: p.data()?['name'] ?? p.data()?['email'] ?? p.id,
    };
    Future<List<Map<String, dynamic>>> query(String collection) async =>
        (await db
                .collection(collection)
                .where('classId', isEqualTo: classId)
                .get())
            .docs
            .map((d) => d.data())
            .where((d) => ids.contains(d['studentId']))
            .toList();
    final quizzes = await query('quiz_results');
    final assessments = await query('pre_assessments');
    final validations = await query('competency_validations');
    final feedback = await query('questionnaire_responses');
    final activities = await query('activity_feedback');
    final modules =
        (await db
                .collection('classes')
                .doc(classId)
                .collection('modules')
                .get())
            .docs;
    final access =
        (await db
                .collection('classes')
                .doc(classId)
                .collection('module_access')
                .get())
            .docs
            .map((d) => d.data())
            .toList();
    final simulations = <Map<String, dynamic>>[];
    for (final id in ids) {
      final docs = await db
          .collection('users')
          .doc(id)
          .collection('simulation_progress')
          .where('classId', isEqualTo: classId)
          .get();
      simulations.addAll(docs.docs.map((d) => {...d.data(), 'studentId': id}));
    }
    return [
      SummarySection(
        'Learning progress summary',
        [
          'Student',
          'Quizzes taken',
          'Quiz average (%)',
          'Simulations attempted',
          'Simulation average (%)',
          'Simulations passed',
        ],
        [
          for (final id in ids)
            [
              names[id],
              quizzes.where((q) => q['studentId'] == id).length,
              _average(
                quizzes.where((q) => q['studentId'] == id),
              ).toStringAsFixed(1),
              simulations.where((q) => q['studentId'] == id).length,
              _average(
                simulations.where((q) => q['studentId'] == id),
              ).toStringAsFixed(1),
              simulations
                  .where((q) => q['studentId'] == id && q['passed'] == true)
                  .length,
            ],
        ],
      ),
      SummarySection(
        'Students',
        ['Student', 'Email', 'NC II'],
        [
          for (final s in students)
            [
              names[s.id],
              s.data()?['email'],
              s.data()?['nc2Passed'] == true ? 'Passed' : 'No recorded pass',
            ],
        ],
      ),
      SummarySection(
        'Module access',
        ['Module', 'Students', 'Accessed', 'Downloaded', 'Requests'],
        [
          for (final module in modules)
            _moduleRow(
              module.data()['title']?.toString() ?? 'Module',
              access.where((r) => r['moduleId'] == module.id),
              ids,
            ),
        ],
      ),
      SummarySection(
        'Quiz results',
        ['Student', 'Quiz', 'Score', 'Total', 'Completed'],
        [
          for (final q in quizzes)
            [
              names[q['studentId']],
              q['quizTitle'] ?? q['quizId'],
              q['score'],
              q['totalPoints'],
              _date(q['completedAt']),
            ],
        ],
      ),
      SummarySection(
        'Pre-assessment',
        ['Student', 'Score', 'Total', 'Competency scores'],
        [
          for (final a in assessments)
            [
              names[a['studentId']],
              a['score'],
              a['totalQuestions'],
              a['competencyScores'],
            ],
        ],
      ),
      SummarySection(
        'Practical validation',
        ['Student', 'Competency', 'Status', 'Notes'],
        [
          for (final a in validations)
            [names[a['studentId']], a['competency'], a['status'], a['notes']],
        ],
      ),
      SummarySection(
        'Simulations',
        ['Student', 'Simulation', 'Score', 'Passed'],
        [
          for (final a in simulations)
            [
              names[a['studentId']],
              a['simulationTitle'] ?? a['simulationId'],
              a['score'],
              a['passed'],
            ],
        ],
      ),
      SummarySection(
        'Teaching and course feedback',
        ['Student', 'Survey', 'Ratings', 'Comment'],
        [
          for (final a in feedback)
            [
              names[a['studentId']],
              a['questionnaireTitle'],
              a['ratings'],
              a['summary'],
            ],
        ],
      ),
      SummarySection(
        'Simulation feedback',
        ['Student', 'Simulation', 'Difficulty', 'Comment'],
        [
          for (final a in activities)
            [
              names[a['studentId']],
              a['simulationTitle'],
              a['difficulty'],
              a['comment'],
            ],
        ],
      ),
    ];
  }

  static List<Object?> _moduleRow(
    String name,
    Iterable<Map<String, dynamic>> records,
    Set<String> ids,
  ) {
    final s = ModuleAccessSummary.fromRecords(records, ids);
    return [name, ids.length, s.accessed, s.downloaded, s.requested];
  }

  static double _average(Iterable<Map<String, dynamic>> records) {
    if (records.isEmpty) return 0;
    double total = 0;
    for (final r in records) {
      final percentage = r['percentage'];
      final score = r['score'];
      final maximum = r['total'] ?? r['totalPoints'] ?? r['totalQuestions'];
      total += percentage is num
          ? percentage.toDouble()
          : score is num && maximum is num && maximum > 0
          ? score / maximum * 100
          : 0;
    }
    return total / records.length;
  }

  static String _date(dynamic value) => value is Timestamp
      ? value.toDate().toIso8601String()
      : value?.toString() ?? '';
}
