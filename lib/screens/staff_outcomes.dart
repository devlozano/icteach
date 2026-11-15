import '../services/workspace_data.dart';
import '../widgets/summary_print_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/student_outcomes.dart';
import '../widgets/outcome_chart.dart';
import 'teacher/progress_tracker_page.dart';
import 'teacher/assessment_review_page.dart';
import '../services/css_gradebook_service.dart';
import '../utils/deped_grading.dart';
import '../widgets/insights_ui.dart';

class StaffOutcomes extends StatelessWidget {
  final bool admin, feedback, trainer;
  const StaffOutcomes({
    super.key,
    this.admin = false,
    this.feedback = false,
    this.trainer = false,
  });
  @override
  Widget build(BuildContext context) {
    if (admin) return _content(null);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: trainer
          ? WorkspaceData.assignedClasses(uid)
          : WorkspaceData.teacherClassDocs(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load class monitoring.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _content(snapshot.data!);
      },
    );
  }

  Widget _content(List<QueryDocumentSnapshot<Map<String, dynamic>>>? classes) {
    if (trainer && !feedback) {
      return _SchoolYearReportScope(
        classes: classes ?? const [],
        builder: (scopedClasses) =>
            _TrainerAssessmentMonitoring(classes: scopedClasses),
      );
    }
    if (!admin && !feedback) {
      return _SchoolYearReportScope(
        classes: classes ?? const [],
        builder: (scopedClasses) =>
            _WeightedAssessmentMonitoring(classes: scopedClasses),
      );
    }
    final studentClasses = <String, String>{};
    for (final c
        in classes ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      for (final id in List<String>.from(
        c.data()['enrolledStudentIds'] ?? [],
      )) {
        studentClasses[id] = c.id;
      }
    }
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: WorkspaceData.students(
        admin ? null : studentClasses.keys.toSet(),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load students. Please reopen this page to retry.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final students = snapshot.data!;
        if (feedback) {
          return _SurveySummary(
            studentIds: students.map((d) => d.id).toSet(),
            admin: admin,
          );
        }
        final passed = students
            .where((s) => s.data()['nc2Passed'] == true)
            .length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SummaryPrintButton(
              title: 'NC II student monitoring',
              load: () async => [
                SummarySection(
                  'Student totals',
                  ['Students', 'NC II passed', 'No recorded pass'],
                  [
                    [students.length, passed, students.length - passed],
                  ],
                ),
                SummarySection(
                  'Student results',
                  ['Student', 'NC II status'],
                  [
                    for (final s in students)
                      [
                        s.data()['name'] ?? s.data()['email'] ?? s.id,
                        s.data()['nc2Passed'] == true
                            ? 'Passed'
                            : 'No recorded pass',
                      ],
                  ],
                ),
              ],
            ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _stat('Number of students', students.length),
                _stat('NC II passed', passed),
                _stat('No recorded pass', students.length - passed),
              ],
            ),
            const SizedBox(height: 16),
            OutcomeChart(
              title: 'NC II student results',
              values: {
                'Passed': passed,
                'No recorded pass': students.length - passed,
              },
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'A missing pass record does not mean the student failed the assessment.',
              ),
            ),
            if (classes != null)
              for (final c in classes)
                Card(
                  child: ListTile(
                    title: Text(
                      c.data()['name']?.toString() ??
                          c.data()['className']?.toString() ??
                          'Class',
                    ),
                    subtitle: const Text(
                      'Lesson progress and assessment results',
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProgressTrackerPage(
                          classId: c.id,
                          className: c.data()['name']?.toString() ?? 'Class',
                        ),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            const Text(
              'Student monitoring',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No students to monitor yet.'),
              ),
            for (final student in students)
              _StudentOutcomeRow(
                key: ValueKey(student.id),
                student: student,
                classId: studentClasses[student.id],
                canEdit: !admin && !trainer,
              ),
          ],
        );
      },
    );
  }

  Widget _stat(String title, int count) => SizedBox(
    width: 230,
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0891B2),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SchoolYearReportScope extends StatefulWidget {
  const _SchoolYearReportScope({required this.classes, required this.builder});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> classes;
  final Widget Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classes,
  )
  builder;

  @override
  State<_SchoolYearReportScope> createState() => _SchoolYearReportScopeState();
}

class _SchoolYearReportScopeState extends State<_SchoolYearReportScope> {
  String? selectedYear;

  @override
  Widget build(BuildContext context) {
    final years =
        widget.classes
            .map((item) => item.data()['schoolYear']?.toString().trim() ?? '')
            .where((year) => year.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final year = selectedYear ?? (years.isEmpty ? null : years.first);
    final scopedClasses = widget.classes
        .where(
          (item) =>
              year == null || item.data()['schoolYear']?.toString() == year,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (years.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: year,
                decoration: const InputDecoration(
                  labelText: 'Report school year',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: years
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selectedYear = value),
              ),
            ),
          ),
        if (years.isNotEmpty) const SizedBox(height: 14),
        widget.builder(scopedClasses),
      ],
    );
  }
}

bool trainerValidationBelongsToAssignedClass(
  Map<String, dynamic> validation,
  Set<String> assignedClassIds,
) => assignedClassIds.contains(validation['classId']?.toString());

class _TrainerAssessmentMonitoring extends StatelessWidget {
  const _TrainerAssessmentMonitoring({required this.classes});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> classes;

  @override
  Widget build(BuildContext context) {
    final trainerId = FirebaseAuth.instance.currentUser!.uid;
    final activeClasses = classes;
    final assignedClassIds = activeClasses.map((item) => item.id).toSet();
    final classNames = {
      for (final classroom in activeClasses)
        classroom.id:
            classroom.data()['name']?.toString() ??
            classroom.data()['className']?.toString() ??
            'Class',
    };
    final studentIds = activeClasses
        .expand(
          (classroom) => List<String>.from(
            classroom.data()['enrolledStudentIds'] as List? ?? const [],
          ),
        )
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InsightsHeader(
          title: 'My assessment results',
          eyebrow: 'TRAINER PRACTICAL VALIDATION',
          icon: Icons.fact_check_outlined,
          subtitle:
              'Review only the practical observations and competency validations you recorded for your assigned students.',
        ),
        const SizedBox(height: 14),
        if (activeClasses.isEmpty)
          const InsightsEmpty(
            icon: Icons.school_outlined,
            title: 'No assigned classes for this school year',
            subtitle: 'Results appear after the principal assigns you a class.',
          )
        else ...[
          InsightsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assigned practical assessments',
                  style: TextStyle(
                    color: insightsNavy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Teacher gradebook scores are managed separately. Use a class below to observe a student and record your own COC 1 or COC 2 validation.',
                  style: TextStyle(color: insightsMuted, height: 1.45),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final classroom in activeClasses)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssessmentReviewPage(
                              classId: classroom.id,
                              className: classNames[classroom.id]!,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: Text(classNames[classroom.id]!),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: studentIds.isEmpty
                ? Stream.value(
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                  )
                : WorkspaceData.students(studentIds),
            builder: (context, studentsSnapshot) {
              final studentNames = {
                for (final student in studentsSnapshot.data ?? const [])
                  student.id:
                      student.data()['name']?.toString() ??
                      student.data()['displayName']?.toString() ??
                      student.data()['email']?.toString() ??
                      'Student',
              };
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('competency_validations')
                    .where('reviewerId', isEqualTo: trainerId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const InsightsEmpty(
                      icon: Icons.error_outline,
                      title: 'Assessment results could not be loaded',
                      subtitle: 'Reopen this page to try again.',
                    );
                  }
                  if (!snapshot.hasData || !studentsSnapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final validations =
                      snapshot.data!.docs
                          .where(
                            (item) => trainerValidationBelongsToAssignedClass(
                              item.data(),
                              assignedClassIds,
                            ),
                          )
                          .toList()
                        ..sort((a, b) {
                          final aTime = a.data()['updatedAt'] as Timestamp?;
                          final bTime = b.data()['updatedAt'] as Timestamp?;
                          return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                            aTime?.millisecondsSinceEpoch ?? 0,
                          );
                        });
                  if (validations.isEmpty) {
                    return const InsightsEmpty(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'No practical validations recorded yet',
                      subtitle:
                          'Open an assigned class, observe the practical task, and save your assessment.',
                    );
                  }
                  final validated = validations
                      .where((item) => item.data()['status'] == 'validated')
                      .length;
                  return InsightsPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InsightsPill('${validations.length} assessments'),
                            InsightsPill('$validated validated'),
                            InsightsPill(
                              '${validations.length - validated} need practice',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        for (final validation in validations) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  validation.data()['status'] == 'validated'
                                  ? const Color(0xFFE8F5EE)
                                  : const Color(0xFFFFF4E5),
                              child: Icon(
                                validation.data()['status'] == 'validated'
                                    ? Icons.check_rounded
                                    : Icons.refresh_rounded,
                                color:
                                    validation.data()['status'] == 'validated'
                                    ? const Color(0xFF287A46)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                            title: Text(
                              '${studentNames[validation.data()['studentId']?.toString()] ?? 'Student'} · ${validation.data()['competency'] ?? 'Competency'}',
                              style: const TextStyle(
                                color: insightsNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${classNames[validation.data()['classId']?.toString()] ?? 'Assigned class'}\n${validation.data()['notes'] ?? 'No observation notes'}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              validation.data()['status'] == 'validated'
                                  ? 'Validated'
                                  : 'Needs practice',
                              style: TextStyle(
                                color:
                                    validation.data()['status'] == 'validated'
                                    ? const Color(0xFF287A46)
                                    : const Color(0xFFB45309),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (validation != validations.last) const Divider(),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WeightedAssessmentMonitoring extends StatelessWidget {
  const _WeightedAssessmentMonitoring({required this.classes});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> classes;

  @override
  Widget build(BuildContext context) {
    final activeClasses = classes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InsightsHeader(
          title: 'Assessment result monitoring',
          eyebrow: 'DEPED WEIGHTED GRADING',
          icon: Icons.fact_check_outlined,
          subtitle:
              'Monitor and manage the same official component grades for every assigned class.',
        ),
        const SizedBox(height: 14),
        const InsightsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Computer Systems Servicing / TechPro',
                style: TextStyle(
                  color: insightsNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InsightsPill('Written Works 15%'),
                  InsightsPill('Performance Tasks 65%'),
                  InsightsPill('Exams 20%'),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Exam grade: Summative Test 1 = 30%, Summative Test 2 = 30%, and Term Exam = 40%. Each learner requires three completed terms for a final grade.',
                style: TextStyle(color: insightsMuted, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (activeClasses.isEmpty)
          const InsightsEmpty(
            icon: Icons.school_outlined,
            title: 'No assigned classes for this school year',
            subtitle:
                'Assessment monitoring appears after a class is assigned.',
          )
        else
          for (final classroom in activeClasses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WeightedClassCard(classroom: classroom),
            ),
      ],
    );
  }
}

class _WeightedClassCard extends StatelessWidget {
  const _WeightedClassCard({required this.classroom});

  final QueryDocumentSnapshot<Map<String, dynamic>> classroom;

  @override
  Widget build(BuildContext context) {
    final data = classroom.data();
    final className = data['name']?.toString() ?? 'Class';
    final teacherId = data['teacherId']?.toString() ?? '';
    final studentIds = List<String>.from(
      data['enrolledStudentIds'] as List? ?? const [],
    );
    final service = CssGradebookService(classroom.id, teacherId: teacherId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.book.snapshots(),
      builder: (context, settings) {
        final config = settings.data?.data();
        return InsightsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          className,
                          style: const TextStyle(
                            color: insightsNavy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${data['sectionCode'] ?? 'No section'} • ${data['teacherName'] ?? 'Teacher'}',
                          style: const TextStyle(color: insightsMuted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProgressTrackerPage(
                          classId: classroom.id,
                          className: className,
                          initialTab: 4,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(
                      config == null ? 'Set up gradebook' : 'Manage grades',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (settings.hasError)
                const Text(
                  'The weighted gradebook could not be loaded.',
                  style: TextStyle(color: Colors.red),
                )
              else if (!settings.hasData)
                const LinearProgressIndicator()
              else if (config == null)
                Text(
                  '${studentIds.length} enrolled • Gradebook setup required',
                  style: const TextStyle(color: insightsMuted),
                )
              else
                _WeightedClassMetrics(
                  service: service,
                  config: config,
                  studentIds: studentIds,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WeightedClassMetrics extends StatelessWidget {
  const _WeightedClassMetrics({
    required this.service,
    required this.config,
    required this.studentIds,
  });

  final CssGradebookService service;
  final Map<String, dynamic> config;
  final List<String> studentIds;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.book.collection('records').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final profile = CssGradingProfile.values.byName(
          config['profile']?.toString() ?? CssGradingProfile.techPro.name,
        );
        final year = (config['year'] as num?)?.toInt() ?? 2026;
        final records = {
          for (final document in snapshot.data!.docs)
            document.id: document.data(),
        };
        DepEdTermResult? termResult(String studentId, int term) {
          return DepEdGrading.calculate(
            CssGradebookService.readScores(
              records['${studentId}_$term'] ?? const {},
            ),
            profile,
            year,
          );
        }

        final finalGrades = <int>[];
        var completedTerms = 0;
        for (final studentId in studentIds) {
          final terms = [
            for (var term = 1; term <= 3; term++)
              termResult(studentId, term)?.grade,
          ];
          completedTerms += terms.whereType<int>().length;
          final grade = DepEdGrading.finalGrade(terms);
          if (grade != null) finalGrades.add(grade);
        }
        final average = finalGrades.isEmpty
            ? null
            : finalGrades.reduce((a, b) => a + b) / finalGrades.length;
        final passing = finalGrades.where((grade) => grade >= 75).length;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InsightsPill('${studentIds.length} learners'),
            InsightsPill('$completedTerms/${studentIds.length * 3} terms'),
            InsightsPill('${finalGrades.length} final grades'),
            InsightsPill(
              average == null
                  ? 'Class average: Incomplete'
                  : 'Class average: ${average.toStringAsFixed(1)}',
            ),
            InsightsPill('$passing meeting 75'),
          ],
        );
      },
    );
  }
}

class _StudentOutcomeRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> student;
  final String? classId;
  final bool canEdit;
  const _StudentOutcomeRow({
    super.key,
    required this.student,
    required this.classId,
    required this.canEdit,
  });
  @override
  State<_StudentOutcomeRow> createState() => _StudentOutcomeRowState();
}

class _StudentOutcomeRowState extends State<_StudentOutcomeRow> {
  bool saving = false;
  Future<void> _update(bool passed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(passed ? 'Record NC II pass?' : 'Remove recorded pass?'),
        content: const Text(
          'This updates the student’s result in the admin reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => saving = true);
    try {
      await StudentOutcomes.setPassed(
        widget.classId!,
        widget.student.id,
        passed,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Result could not be saved. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.student.data();
    final name =
        data['name']?.toString() ??
        [data['firstName'], data['lastName']].whereType<String>().join(' ');
    final passed = data['nc2Passed'] == true;
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(name.isEmpty ? 'Student' : name),
        subtitle: Text(passed ? 'NC II passed' : 'No recorded NC II pass'),
        trailing: widget.canEdit
            ? Switch(value: passed, onChanged: saving ? null : _update)
            : Icon(
                passed ? Icons.verified : Icons.pending_outlined,
                color: passed ? Colors.teal : Colors.grey,
              ),
      ),
    );
  }
}

class _SurveySummary extends StatelessWidget {
  final Set<String> studentIds;
  final bool admin;
  const _SurveySummary({required this.studentIds, required this.admin});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('app_helpfulness_surveys')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Could not load feedback. Please reopen this page to retry.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final responses = snapshot.data!.docs
          .where((d) => studentIds.contains(d.id))
          .map((d) => d.data())
          .toList();
      final ratings = responses
          .expand(
            (response) => ((response['ratings'] as Map?)?.values ?? const []),
          )
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList();
      final average = ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length;
      final responseRate = studentIds.isEmpty
          ? 0
          : (responses.length / studentIds.length * 100).round();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2B4A), Color(0xFF176B87)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.forum_rounded, color: Color(0xFF67E8F9), size: 34),
                SizedBox(height: 14),
                Text(
                  'Student feedback',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'See participation, rating patterns, and student comments in one view.',
                  style: TextStyle(color: Color(0xFFD7EAF1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeedbackMetric(
                label: 'Responses',
                value: '${responses.length}/${studentIds.length}',
                icon: Icons.how_to_vote_rounded,
              ),
              _FeedbackMetric(
                label: 'Participation',
                value: '$responseRate%',
                icon: Icons.donut_large_rounded,
              ),
              _FeedbackMetric(
                label: 'Average rating',
                value: ratings.isEmpty
                    ? '—'
                    : '${average.toStringAsFixed(1)}/5',
                icon: Icons.star_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SummaryPrintButton(
            title: 'Student helpfulness survey',
            load: () async => [
              SummarySection(
                'Participation',
                ['Students', 'Responses'],
                [
                  [studentIds.length, responses.length],
                ],
              ),
              SummarySection(
                'Rating summary',
                ['Question', 'Average / 5', '1', '2', '3', '4', '5'],
                [
                  for (var i = 0; i < helpfulnessPrompts.length; i++)
                    [
                      helpfulnessPrompts[i],
                      RatingSummary(
                        responses.map((r) => (r['ratings'] as Map?)?['q$i']),
                      ).average.toStringAsFixed(2),
                      ...RatingSummary(
                        responses.map((r) => (r['ratings'] as Map?)?['q$i']),
                      ).counts,
                    ],
                ],
              ),
              SummarySection(
                'Comments',
                ['Comment'],
                [
                  for (final r in responses) [r['comment'] ?? ''],
                ],
              ),
            ],
          ),
          const Text(
            'Does ICTeach help students? Each student contributes one current response. 1 = Strongly disagree; 5 = Strongly agree.',
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < helpfulnessPrompts.length; i++)
            _question(i, responses),
          const SizedBox(height: 16),
          const Text(
            'Student comments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          for (final r in responses.where(
            (r) => (r['comment']?.toString() ?? '').trim().isNotEmpty,
          ))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(r['comment'].toString()),
              ),
            ),
          if (responses.isEmpty)
            const Text(
              'Survey results will appear here after students submit feedback.',
            ),
        ],
      );
    },
  );
  Widget _question(int i, List<Map<String, dynamic>> responses) {
    final summary = RatingSummary(
      responses.map((r) => (r['ratings'] as Map?)?['q$i']),
    );
    return OutcomeChart(
      title:
          '${helpfulnessPrompts[i]}\n${summary.total == 0 ? 'No ratings yet' : '${summary.average.toStringAsFixed(1)} / 5 average · ${summary.total} responses'}',
      values: {
        for (var score = 1; score <= 5; score++)
          '$score': summary.counts[score - 1],
      },
    );
  }
}

class _FeedbackMetric extends StatelessWidget {
  const _FeedbackMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCE5ED)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE0F2FE),
          child: Icon(icon, color: const Color(0xFF0369A1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
