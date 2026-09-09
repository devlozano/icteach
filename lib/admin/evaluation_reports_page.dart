import '../../widgets/summary_print_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EvaluationReportsPage extends StatelessWidget {
  const EvaluationReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: const Text('Evaluation Reports'),
          actions: [
            SummaryPrintButton(
              title: 'Evaluation summaries',
              load: () async {
                final responses = await FirebaseFirestore.instance
                    .collection('questionnaire_responses')
                    .get();
                final feedback = await FirebaseFirestore.instance
                    .collection('activity_feedback')
                    .get();
                return [
                  SummarySection(
                    'Course and system feedback',
                    ['Student', 'Survey', 'Ratings', 'Comment'],
                    [
                      for (final d in responses.docs)
                        [
                          d.data()['studentName'],
                          d.data()['questionnaireTitle'],
                          d.data()['ratings'],
                          d.data()['summary'],
                        ],
                    ],
                  ),
                  SummarySection(
                    'Simulation feedback',
                    ['Simulation', 'Difficulty', 'Comment'],
                    [
                      for (final d in feedback.docs)
                        [
                          d.data()['simulationTitle'],
                          d.data()['difficulty'],
                          d.data()['comment'],
                        ],
                    ],
                  ),
                ];
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFF94A3B8),
            indicatorColor: Color(0xFF22D3EE),
            tabs: [
              Tab(text: 'Course & System'),
              Tab(text: 'Simulation Feedback'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_QuestionnaireResponses(), _SimulationFeedback()],
        ),
      ),
    );
  }
}

class _QuestionnaireResponses extends StatelessWidget {
  const _QuestionnaireResponses();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('questionnaire_responses')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final responses = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => _millis(
              b.data()['submittedAt'],
            ).compareTo(_millis(a.data()['submittedAt'])),
          );
        if (responses.isEmpty) {
          return const _ReportEmpty(
            message: 'No course, teaching, or system evaluation responses yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: responses.length,
          itemBuilder: (context, index) {
            final data = responses[index].data();
            final ratings = Map<String, dynamic>.from(
              (data['ratings'] as Map?) ?? const {},
            );
            final ratingValues = ratings.values.whereType<num>().toList();
            final average = ratingValues.isEmpty
                ? 0.0
                : ratingValues.fold<double>(
                        0,
                        (total, rating) => total + rating,
                      ) /
                      ratingValues.length;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Text(
                    average == 0 ? '-' : average.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  data['questionnaireTitle']?.toString() ?? 'Evaluation',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${data['studentName']?.toString() ?? 'Student'} • '
                  '${data['questionnaireType']?.toString().replaceAll('_', ' ') ?? 'feedback'}\n'
                  '${data['summary']?.toString().trim().isNotEmpty == true ? data['summary'] : 'No written response'}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _SimulationFeedback extends StatelessWidget {
  const _SimulationFeedback();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('activity_feedback')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final feedback = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => _millis(
              b.data()['createdAt'],
            ).compareTo(_millis(a.data()['createdAt'])),
          );
        if (feedback.isEmpty) {
          return const _ReportEmpty(message: 'No simulation feedback yet.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: feedback.length,
          itemBuilder: (context, index) {
            final data = feedback[index].data();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFEDD5),
                  child: Text(data['difficulty']?.toString() ?? '-'),
                ),
                title: Text(
                  data['simulationTitle']?.toString() ?? 'Simulation feedback',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  data['comment']?.toString().trim().isNotEmpty == true
                      ? data['comment'].toString()
                      : 'No written comment',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportEmpty extends StatelessWidget {
  const _ReportEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

int _millis(dynamic value) {
  return value is Timestamp ? value.millisecondsSinceEpoch : 0;
}
