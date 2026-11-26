import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'summary_pdf_service.dart';
import 'module_access_service.dart';
import 'css_gradebook_service.dart';
import '../utils/deped_grading.dart';

enum ClassSummaryPrintPurpose { grades, progress, modules }

class ClassSummaryService {
  static List<SummarySection> sectionsForPrint(
    ClassSummaryPrintPurpose purpose,
    List<SummarySection> sections,
  ) {
    final titles = switch (purpose) {
      ClassSummaryPrintPurpose.grades => const {
        'Learning progress summary',
        'Teacher grade summary',
        'Trainer grade summary',
        'Trainer practical validation',
      },
      ClassSummaryPrintPurpose.progress => const {'Learning progress summary'},
      ClassSummaryPrintPurpose.modules => const {'Module access'},
    };
    final selected = sections
        .where((section) => titles.contains(section.title))
        .toList();
    if (selected.isNotEmpty || purpose != ClassSummaryPrintPurpose.progress) {
      return selected;
    }
    // Trainer reports do not contain the teacher-wide learning-progress table.
    // Print the trainer-owned grading and validation summaries instead of
    // passing an empty document to the printing plugin.
    const trainerTitles = {
      'Trainer grade summary',
      'Trainer practical validation',
    };
    return sections
        .where((section) => trainerTitles.contains(section.title))
        .toList();
  }

  static Future<List<SummarySection>> loadForPrint(
    String classId,
    ClassSummaryPrintPurpose purpose, {
    String? role,
    String? userId,
  }) async => sectionsForPrint(
    purpose,
    await load(classId, role: role, userId: userId),
  );

  static List<SummarySection> sectionsForRole(
    String role,
    List<SummarySection> sections,
  ) {
    final byTitle = {for (final section in sections) section.title: section};
    if (role == 'trainer') {
      return [
        if (byTitle['Students'] case final section?) section,
        if (byTitle['Trainer grade summary'] case final section?) section,
        if (byTitle['Trainer practical validation'] case final section?)
          section,
      ];
    }
    if (role == 'teacher') {
      const titles = [
        'Learning progress summary',
        'Teacher grade summary',
        'Students',
        'Module access',
        'Quiz results',
        'Pre-assessment',
        'Simulations',
      ];
      return [
        for (final title in titles)
          if (byTitle[title] case final section?) section,
      ];
    }
    return sections;
  }

  static Future<List<SummarySection>> load(
    String classId, {
    String? role,
    String? userId,
  }) async {
    final db = FirebaseFirestore.instance;
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    final resolvedRole =
        role ??
        (uid == null
            ? 'admin'
            : (await db.collection('users').doc(uid).get())
                      .data()?['role']
                      ?.toString() ??
                  'admin');
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
    final sections = await Future.wait([
      query('quiz_results'),
      query('pre_assessments'),
      query('competency_validations'),
      query('questionnaire_responses'),
      query('activity_feedback'),
    ]);
    final quizzes = sections[0],
        assessments = sections[1],
        validations = sections[2]
            .where(
              (record) =>
                  resolvedRole != 'trainer' || record['reviewerId'] == uid,
            )
            .toList(),
        feedback = sections[3],
        activities = sections[4];
    final content = await Future.wait([
      db.collection('classes').doc(classId).collection('modules').get(),
      db.collection('classes').doc(classId).collection('module_access').get(),
    ]);
    final modules = content[0].docs;
    final access = content[1].docs.map((d) => d.data()).toList();
    final gradeOwner = resolvedRole == 'trainer'
        ? uid
        : classroom['teacherId']?.toString();
    final gradeCollection = resolvedRole == 'trainer'
        ? 'trainer_gradebooks'
        : 'css_gradebooks';
    final gradeRows = <List<Object?>>[];
    if (gradeOwner != null && gradeOwner.isNotEmpty) {
      final book = db
          .collection(gradeCollection)
          .doc(gradeOwner)
          .collection('classes')
          .doc(classId);
      final configuration = (await book.get()).data();
      if (configuration != null) {
        final profile = CssGradingProfile.values
            .asNameMap()[configuration['profile']];
        final year = configuration['year'];
        if (profile != null && year is int) {
          final records = {
            for (final record in (await book.collection('records').get()).docs)
              record.id: record.data(),
          };
          for (final studentId in ids) {
            final termGrades = <int?>[
              for (var term = 1; term <= 3; term++)
                DepEdGrading.calculate(
                  CssGradebookService.readScores(
                    records['${studentId}_$term'] ?? const {},
                  ),
                  profile,
                  year,
                )?.grade,
            ];
            final finalGrade = DepEdGrading.finalGrade(termGrades);
            gradeRows.add([
              names[studentId],
              ...termGrades.map((grade) => grade ?? 'Incomplete'),
              finalGrade ?? 'Incomplete',
              finalGrade == null
                  ? 'Incomplete'
                  : DepEdGrading.remark(termGrades),
            ]);
          }
        }
      }
    }
    final simulations = <Map<String, dynamic>>[];
    final studentIds = ids.toList();
    for (var offset = 0; offset < studentIds.length; offset += 10) {
      final batch = studentIds.skip(offset).take(10).toList();
      final progress = await Future.wait(
        batch.map(
          (id) => db
              .collection('users')
              .doc(id)
              .collection('simulation_progress')
              .where('classId', isEqualTo: classId)
              .get(),
        ),
      );
      for (var i = 0; i < batch.length; i++) {
        simulations.addAll(
          progress[i].docs.map((d) => {...d.data(), 'studentId': batch[i]}),
        );
      }
    }
    final reportSections = [
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
        resolvedRole == 'trainer'
            ? 'Trainer grade summary'
            : 'Teacher grade summary',
        const [
          'Student',
          'Term 1',
          'Term 2',
          'Term 3',
          'Final grade',
          'Remark',
        ],
        gradeRows,
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
        resolvedRole == 'trainer'
            ? 'Trainer practical validation'
            : 'Practical validation',
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
    return sectionsForRole(resolvedRole, reportSections);
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
