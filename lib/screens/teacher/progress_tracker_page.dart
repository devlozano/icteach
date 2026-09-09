import '../../widgets/summary_print_button.dart';
import '../../services/class_summary_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'activity_timeline_page.dart';
import '../../services/workspace_preferences.dart';
import 'assessment_review_page.dart';
import '../../widgets/leaderboard_chart.dart';
import '../../services/report_export_service.dart';

class ProgressTrackerPage extends StatefulWidget {
  final String classId;
  final String className;

  const ProgressTrackerPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ProgressTrackerPage> createState() => _ProgressTrackerPageState();
}

class _ProgressTrackerPageState extends State<ProgressTrackerPage> {
  late Future<_ClassInsights> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _insightsFuture = _loadInsights();
  }

  Future<_ClassInsights> _loadInsights() async {
    final db = FirebaseFirestore.instance;
    final classSnapshot = await db
        .collection('classes')
        .doc(widget.classId)
        .get();
    final classData = classSnapshot.data() ?? <String, dynamic>{};
    final memberIds = List<String>.from(
      (classData['enrolledStudentIds'] as List?) ?? const [],
    );

    final userSnapshots = await Future.wait(
      memberIds.map((id) => db.collection('users').doc(id).get()),
    );
    final studentIds = <String>[];
    final studentNames = <String, String>{};
    for (var index = 0; index < memberIds.length; index++) {
      final data = userSnapshots[index].data() ?? <String, dynamic>{};
      if (data['role'] != 'student') continue;
      studentIds.add(memberIds[index]);
      studentNames[memberIds[index]] =
          data['name']?.toString() ?? data['email']?.toString() ?? 'Student';
    }

    final quizSnapshot = await db
        .collection('quiz_results')
        .where('classId', isEqualTo: widget.classId)
        .get();
    final feedbackSnapshot = await db
        .collection('activity_feedback')
        .where('classId', isEqualTo: widget.classId)
        .get();
    final responseSnapshot = await db
        .collection('questionnaire_responses')
        .where('classId', isEqualTo: widget.classId)
        .get();

    final simulationSnapshots = await Future.wait(
      studentIds.map(
        (id) => db
            .collection('users')
            .doc(id)
            .collection('simulation_progress')
            .where('classId', isEqualTo: widget.classId)
            .get(),
      ),
    );

    final students = <_StudentInsight>[];
    for (var index = 0; index < studentIds.length; index++) {
      final studentId = studentIds[index];
      final quizzes = quizSnapshot.docs
          .where((doc) => doc.data()['studentId']?.toString() == studentId)
          .toList();
      final simulations = simulationSnapshots[index].docs;
      final quizAverage = _average(
        quizzes.map((doc) => _percentage(doc.data())).toList(),
      );
      final simulationAverage = _average(
        simulations.map((doc) => _percentage(doc.data())).toList(),
      );
      final lastActivity = _latest([
        ...quizzes.map(
          (doc) => _timestamp(doc.data(), ['completedAt', 'date']),
        ),
        ...simulations.map(
          (doc) => _timestamp(doc.data(), ['completedAt', 'updatedAt']),
        ),
      ]);

      students.add(
        _StudentInsight(
          id: studentId,
          name: studentNames[studentId] ?? 'Student',
          quizCount: quizzes.length,
          quizAverage: quizAverage,
          simulationCount: simulations.length,
          simulationAverage: simulationAverage,
          passedSimulations: simulations
              .where((doc) => doc.data()['passed'] == true)
              .length,
          lastActivity: lastActivity,
        ),
      );
    }
    students.sort((a, b) => b.overallAverage.compareTo(a.overallAverage));

    return _ClassInsights(
      students: students,
      simulationRecords: simulationSnapshots
          .expand((snapshot) => snapshot.docs)
          .map((doc) => doc.data())
          .toList(),
      feedback: feedbackSnapshot.docs.map((doc) => doc.data()).toList()
        ..sort(
          (a, b) => (_timestamp(b, ['createdAt']) ?? DateTime(2000)).compareTo(
            _timestamp(a, ['createdAt']) ?? DateTime(2000),
          ),
        ),
      questionnaireResponses: responseSnapshot.docs
          .map((doc) => doc.data())
          .toList(),
    );
  }

  double _percentage(Map<String, dynamic> data) {
    final percentage = data['percentage'];
    if (percentage is num) return percentage.toDouble();
    final score = data['score'];
    final total =
        data['total'] ?? data['totalPoints'] ?? data['totalQuestions'];
    if (score is num && total is num && total > 0) {
      return score / total * 100;
    }
    return 0;
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  DateTime? _timestamp(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    return null;
  }

  DateTime? _latest(Iterable<DateTime?> values) {
    final dates = values.whereType<DateTime>().toList()..sort();
    return dates.isEmpty ? null : dates.last;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: WorkspacePreferences.tab('insights_${widget.classId}', 4),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B2B4A),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Class Insights',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                widget.className,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            SummaryPrintButton(
              title: 'Class summary - ${widget.className}',
              load: () => ClassSummaryService.load(widget.classId),
            ),
            IconButton(
              tooltip: 'Student activity timeline',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityTimelinePage(classId: widget.classId),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Pre-assessments and practical validation',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssessmentReviewPage(
                    classId: widget.classId,
                    className: widget.className,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Export grades (CSV)',
              icon: const Icon(Icons.download_outlined),
              onPressed: () async {
                try {
                  final insights = await _insightsFuture;
                  await ReportExportService.shareCsv('icteach-grades.csv', [
                    [
                      'Student',
                      'Quizzes taken',
                      'Quiz average (%)',
                      'Simulations attempted',
                      'Simulation average (%)',
                      'Simulations passed',
                    ],
                    ...insights.students.map(
                      (s) => [
                        s.name,
                        s.quizCount,
                        s.quizAverage.toStringAsFixed(1),
                        s.simulationCount,
                        s.simulationAverage.toStringAsFixed(1),
                        s.passedSimulations,
                      ],
                    ),
                  ]);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to export grades. Please retry.'),
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Refresh data',
              onPressed: () => setState(_refresh),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            onTap: (index) => WorkspacePreferences.saveTab(
              'insights_${widget.classId}',
              index,
            ),
            isScrollable: true,
            indicatorColor: Color(0xFF60E3DD),
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFB8C7D6),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Students'),
              Tab(text: 'Simulations'),
              Tab(text: 'Feedback'),
            ],
          ),
        ),
        body: FutureBuilder<_ClassInsights>(
          future: _insightsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: () => setState(_refresh),
              );
            }
            final insights = snapshot.data!;
            return TabBarView(
              children: [
                _OverviewTab(insights: insights),
                _StudentsTab(students: insights.students),
                _SimulationsTab(records: insights.simulationRecords),
                _FeedbackTab(
                  feedback: insights.feedback,
                  questionnaireResponses: insights.questionnaireResponses,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.insights});

  final _ClassInsights insights;

  @override
  Widget build(BuildContext context) {
    final studentsWithActivity = insights.students
        .where((student) => student.hasActivity)
        .length;
    final avg = insights.students.isEmpty
        ? 0.0
        : insights.students
                  .map((student) => student.overallAverage)
                  .reduce((a, b) => a + b) /
              insights.students.length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _MetricCard(
              label: 'Enrolled students',
              value: '${insights.students.length}',
              icon: Icons.groups_rounded,
              color: const Color(0xFF2563EB),
            ),
            _MetricCard(
              label: 'Students active',
              value: '$studentsWithActivity',
              icon: Icons.bolt_rounded,
              color: const Color(0xFF0F9D7A),
            ),
            _MetricCard(
              label: 'Combined average',
              value: '${avg.round()}%',
              icon: Icons.analytics_rounded,
              color: const Color(0xFF7C3AED),
            ),
            _MetricCard(
              label: 'Student feedback',
              value:
                  '${insights.feedback.length + insights.questionnaireResponses.length}',
              icon: Icons.rate_review_rounded,
              color: const Color(0xFFEA7C16),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LeaderboardChart(
          title: 'Class performance',
          entries: insights.students
              .where((s) => s.hasActivity)
              .map(
                (s) => <String, dynamic>{
                  'studentName': s.name,
                  'percentage': s.overallAverage,
                },
              )
              .toList(),
        ),
        const SizedBox(height: 22),
        const Text(
          'Students needing attention',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...insights.students
            .where(
              (student) => !student.hasActivity || student.overallAverage < 75,
            )
            .map(
              (student) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: student.hasActivity
                        ? Colors.orange.shade100
                        : Colors.red.shade100,
                    child: Icon(
                      student.hasActivity
                          ? Icons.trending_down_rounded
                          : Icons.hourglass_empty_rounded,
                      color: student.hasActivity ? Colors.orange : Colors.red,
                    ),
                  ),
                  title: Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    student.hasActivity
                        ? 'Combined result ${student.overallAverage.round()}%'
                        : 'No quiz or simulation activity yet',
                  ),
                ),
              ),
            ),
        if (!insights.students.any(
          (student) => !student.hasActivity || student.overallAverage < 75,
        ))
          const _EmptyState(
            icon: Icons.verified_rounded,
            title: 'Everyone is on track',
            subtitle: 'No inactive or below-threshold student was detected.',
          ),
      ],
    );
  }
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({required this.students});

  final List<_StudentInsight> students;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const _EmptyState(
        icon: Icons.group_off_rounded,
        title: 'No enrolled students',
        subtitle: 'Students will appear here after joining the class.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: students.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0B2B4A),
                  foregroundColor: Colors.white,
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 5,
                        children: [
                          Text(
                            '${student.quizCount} quizzes • ${student.quizAverage.round()}%',
                          ),
                          Text(
                            '${student.simulationCount} simulations • ${student.simulationAverage.round()}%',
                          ),
                          Text('Last: ${_formatDate(student.lastActivity)}'),
                        ],
                      ),
                    ],
                  ),
                ),
                _ScoreBadge(value: student.overallAverage),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SimulationsTab extends StatelessWidget {
  const _SimulationsTab({required this.records});

  final List<Map<String, dynamic>> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyState(
        icon: Icons.precision_manufacturing_rounded,
        title: 'No simulation attempts',
        subtitle: 'Completed student simulations will appear here.',
      );
    }
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final title =
          record['simulationTitle']?.toString() ??
          record['title']?.toString() ??
          record['simulationId']?.toString() ??
          'Simulation';
      grouped.putIfAbsent(title, () => []).add(record);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: grouped.entries.map((entry) {
        final passed = entry.value
            .where((item) => item['passed'] == true)
            .length;
        final avg =
            entry.value
                .map((item) => (item['percentage'] as num?)?.toDouble() ?? 0)
                .fold<double>(0, (total, value) => total + value) /
            entry.value.length;
        final retries = entry.value
            .map((item) => ((item['attempts'] as num?)?.toInt() ?? 1) - 1)
            .fold<int>(0, (total, value) => total + value.clamp(0, 999));
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(Icons.memory_rounded, color: Color(0xFF0369A1)),
            ),
            title: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${entry.value.length} completion(s) • $passed passed • $retries retries',
            ),
            trailing: _ScoreBadge(value: avg),
          ),
        );
      }).toList(),
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab({
    required this.feedback,
    required this.questionnaireResponses,
  });

  final List<Map<String, dynamic>> feedback;
  final List<Map<String, dynamic>> questionnaireResponses;

  @override
  Widget build(BuildContext context) {
    if (feedback.isEmpty && questionnaireResponses.isEmpty) {
      return const _EmptyState(
        icon: Icons.mark_chat_unread_outlined,
        title: 'No feedback submitted',
        subtitle:
            'Simulation and teaching questionnaire responses appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (questionnaireResponses.isNotEmpty) ...[
          const Text(
            'Teaching questionnaires',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...questionnaireResponses.map(
            (response) => Card(
              child: ListTile(
                leading: const Icon(Icons.fact_check_rounded),
                title: Text(
                  response['questionnaireTitle']?.toString() ?? 'Questionnaire',
                ),
                subtitle: Text(
                  '${response['studentName'] ?? 'Student'}\n'
                  '${response['summary'] ?? 'Response submitted'}\n'
                  '${(Map<String, dynamic>.from(response['ratings'] as Map? ?? {}).entries.map((e) => '${(response['ratingPrompts'] as Map?)?[e.key] ?? e.key}: ${e.value}/5')).join('\n')}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (feedback.isNotEmpty) ...[
          const Text(
            'Simulation feedback',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...feedback.map(
            (item) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(item['difficulty']?.toString() ?? '-'),
                ),
                title: Text(
                  item['simulationTitle']?.toString() ?? 'Simulation',
                ),
                subtitle: Text(
                  item['comment']?.toString().trim().isNotEmpty == true
                      ? item['comment'].toString()
                      : 'No written comment',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, style: const TextStyle(color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 75
        ? Colors.green
        : value > 0
        ? Colors.orange
        : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${value.round()}%',
        style: TextStyle(color: color.shade700, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.blueGrey.shade200),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text('Unable to load class insights'),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'No activity';
  final date = value.toLocal();
  return '${date.month}/${date.day}/${date.year}';
}

class _ClassInsights {
  const _ClassInsights({
    required this.students,
    required this.simulationRecords,
    required this.feedback,
    required this.questionnaireResponses,
  });

  final List<_StudentInsight> students;
  final List<Map<String, dynamic>> simulationRecords;
  final List<Map<String, dynamic>> feedback;
  final List<Map<String, dynamic>> questionnaireResponses;
}

class _StudentInsight {
  const _StudentInsight({
    required this.id,
    required this.name,
    required this.quizCount,
    required this.quizAverage,
    required this.simulationCount,
    required this.simulationAverage,
    required this.passedSimulations,
    required this.lastActivity,
  });

  final String id;
  final String name;
  final int quizCount;
  final double quizAverage;
  final int simulationCount;
  final double simulationAverage;
  final int passedSimulations;
  final DateTime? lastActivity;

  bool get hasActivity => quizCount > 0 || simulationCount > 0;

  double get overallAverage {
    final values = <double>[
      if (quizCount > 0) quizAverage,
      if (simulationCount > 0) simulationAverage,
    ];
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
