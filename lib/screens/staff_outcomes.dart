import '../widgets/summary_print_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/student_outcomes.dart';
import '../widgets/outcome_chart.dart';
import 'teacher/progress_tracker_page.dart';

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
    if (trainer) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('classes')
            .snapshots(),
        builder: (context, memberships) {
          if (memberships.hasError) {
            return const Text('Could not load your classes.');
          }
          if (!memberships.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = memberships.data!.docs
              .map((d) => d.data()['classId']?.toString() ?? d.id)
              .toSet();
          return _classes(
            FirebaseFirestore.instance.collection('classes').snapshots(),
            ids,
          );
        },
      );
    }
    return _classes(
      FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: uid)
          .snapshots(),
      null,
    );
  }

  Widget _classes(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    Set<String>? ids,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Could not load class monitoring.');
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final classes = snapshot.data!.docs
          .where((d) => ids == null || ids.contains(d.id))
          .toList();
      return _content(classes);
    },
  );
  Widget _content(List<QueryDocumentSnapshot<Map<String, dynamic>>>? classes) {
    final studentClasses = <String, String>{};
    for (final c
        in classes ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      for (final id in List<String>.from(
        c.data()['enrolledStudentIds'] ?? [],
      )) {
        studentClasses[id] = c.id;
      }
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load students. Please reopen this page to retry.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final students = snapshot.data!.docs
            .where((d) => admin || studentClasses.containsKey(d.id))
            .toList();
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text(
            '${responses.length} of ${studentIds.length} students responded',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
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
