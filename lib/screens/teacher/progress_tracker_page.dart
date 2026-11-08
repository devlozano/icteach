import '../../widgets/insights_ui.dart';
import '../../services/css_gradebook_service.dart';
import 'css_gradebook_page.dart';
import '../../widgets/summary_print_button.dart';
import '../../services/class_summary_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'activity_timeline_page.dart';
import '../../services/workspace_preferences.dart';
import 'assessment_review_page.dart';
import '../../widgets/leaderboard_chart.dart';
import '../../services/report_export_service.dart';

part 'class_insights_tabs.dart';

class ProgressTrackerPage extends StatefulWidget {
  final String classId;
  final String className;
  final FirebaseFirestore? firestore;
  final CssGradebookService? gradebookService;

  const ProgressTrackerPage({
    super.key,
    required this.classId,
    required this.className,
    this.firestore,
    this.gradebookService,
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
    final db = widget.firestore ?? FirebaseFirestore.instance;
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
      length: 5,
      initialIndex: WorkspacePreferences.tab('insights_${widget.classId}', 5),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 26
              ? 80
              : 64,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'CLASS TOOLS',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: Color(0xFFB8C7D6),
                            ),
                          ),
                          const SizedBox(width: 12),

                          SummaryPrintButton(
                            title: 'Class summary - ${widget.className}',
                            load: () =>
                                ClassSummaryService.load(widget.classId),
                          ),
                          IconButton(
                            tooltip: 'Student activity timeline',
                            icon: const Icon(Icons.history),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityTimelinePage(
                                  classId: widget.classId,
                                ),
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
                            tooltip: 'Export activity progress (CSV)',
                            icon: const Icon(Icons.download_outlined),
                            onPressed: () async {
                              try {
                                final insights = await _insightsFuture;
                                await ReportExportService.shareCsv(
                                  'icteach-activity-progress.csv',
                                  [
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
                                  ],
                                );
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Unable to export progress. Please retry.',
                                      ),
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
                      ),
                    ),
                  ),
                ),
                TabBar(
                  onTap: (index) => WorkspacePreferences.saveTab(
                    'insights_${widget.classId}',
                    index,
                  ),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorColor: Color(0xFF60E3DD),
                  labelColor: Colors.white,
                  unselectedLabelColor: Color(0xFFB8C7D6),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Students'),
                    Tab(text: 'Simulations'),
                    Tab(text: 'Feedback'),
                    Tab(text: 'Grades'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: FutureBuilder<_ClassInsights>(
          future: _insightsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(onRetry: () => setState(_refresh));
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
                CssGradebookPage(
                  service: widget.gradebookService,
                  classId: widget.classId,
                  students: {
                    for (final student in insights.students)
                      student.id: student.name,
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

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
            const Text(
              'Check your connection and class access, then try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Date not recorded';
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
