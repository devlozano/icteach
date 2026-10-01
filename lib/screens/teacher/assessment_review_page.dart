import '../../widgets/summary_print_button.dart';
import '../../services/class_summary_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/pre_assessment_data.dart';
import '../../services/content_access_service.dart';

class AssessmentReviewPage extends StatefulWidget {
  final String classId;
  final String className;
  const AssessmentReviewPage({
    super.key,
    required this.classId,
    required this.className,
  });
  @override
  State<AssessmentReviewPage> createState() => _AssessmentReviewPageState();
}

class _AssessmentReviewPageState extends State<AssessmentReviewPage> {
  late final _staff = ContentAccessService.isClassStaff(widget.classId);
  late final _records = FirebaseFirestore.instance
      .collection('pre_assessments')
      .where('classId', isEqualTo: widget.classId)
      .snapshots();

  Future<void> _review(String studentId, String competency) async {
    final notes = TextEditingController();
    String status = 'needs_practice';
    bool observed = false;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$competency practical validation'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Record your direct observation and supporting evidence. A quiz or simulation score alone does not establish practical competency. This is an instructional record, not a TESDA certificate.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(
                        value: 'needs_practice',
                        child: Text('Needs more practice'),
                      ),
                      DropdownMenuItem(
                        value: 'validated',
                        child: Text('Validated by trainer'),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => status = v!),
                    decoration: const InputDecoration(labelText: 'Outcome'),
                  ),
                  CheckboxListTile(
                    value: observed,
                    onChanged: (v) =>
                        setDialogState(() => observed = v ?? false),
                    title: const Text(
                      'I observed the practical task and checked the evidence',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 4,
                    maxLength: 1500,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Task, observations and evidence',
                      helperText:
                          'Include areas needing practice or evidence supporting validation.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  notes.text.trim().length < 10 ||
                      (status == 'validated' && !observed)
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
    final evidence = notes.text.trim();
    // The dialog route may still be animating; defer controller disposal.
    Future<void>.delayed(const Duration(seconds: 1), notes.dispose);
    if (save != true) return;
    try {
      if (!await ContentAccessService.isClassStaff(widget.classId)) {
        throw StateError('Staff access required.');
      }
      final data = {
        'classId': widget.classId,
        'studentId': studentId,
        'competency': competency,
        'status': status,
        'observed': observed,
        'notes': evidence,
        'reviewerId': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final ref = FirebaseFirestore.instance
          .collection('competency_validations')
          .doc('${widget.classId}_${studentId}_$competency');
      final batch = FirebaseFirestore.instance.batch();
      batch.set(ref, data);
      batch.set(ref.collection('history').doc(), data);
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Practical review saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review could not be saved. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0B2B4A),
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assessments',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            widget.className,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        SummaryPrintButton(
          title: 'Assessment summary - ${widget.className}',
          load: () => ClassSummaryService.load(widget.classId),
        ),
      ],
    ),
    body: FutureBuilder<bool>(
      future: _staff,
      builder: (context, staff) {
        if (staff.hasError) {
          return const Center(
            child: Text('Unable to verify staff access. Reopen to retry.'),
          );
        }
        if (!staff.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (staff.data != true) {
          return const Center(child: Text('Class staff access required.'));
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _records,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Assessment results could not be loaded. Reopen to retry.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = snapshot.data!.docs
                .where((d) => PreAssessmentData.isComplete(d.data()))
                .toList();
            if (records.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No completed diagnostics yet. Students take the diagnostic when they first open Modules.',
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B2B4A), Color(0xFF176B87)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Wrap(
                    spacing: 22,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const SizedBox(
                        width: 430,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Computer Systems Servicing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Review diagnostic readiness and record direct practical observations for COC 1 and COC 2.',
                              style: TextStyle(
                                color: Color(0xFFD7EAF1),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _AssessmentMetric(
                        value: '${records.length}',
                        label: 'Completed',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Learner diagnostic records',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                for (final doc in records)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFDCE5ED)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFE0F2FE),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  doc.data()['studentName']?.toString() ??
                                      'Student',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _DiagnosticScore(
                                score:
                                    (doc.data()['score'] as num?)?.toInt() ?? 0,
                                total:
                                    (doc.data()['totalQuestions'] as num?)
                                        ?.toInt() ??
                                    0,
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          for (final competency in ['COC1', 'COC2'])
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                title: Text(
                                  '$competency · ${(doc.data()['competencyScores'] as Map?)?[competency] ?? 0}/6 correct',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle:
                                    StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                      stream: FirebaseFirestore.instance
                                          .collection('competency_validations')
                                          .doc(
                                            '${widget.classId}_${doc.data()['studentId']}_$competency',
                                          )
                                          .snapshots(),
                                      builder: (context, review) {
                                        if (review.hasError) {
                                          return const Text(
                                            'Unable to load practical review',
                                          );
                                        }
                                        if (!review.hasData) {
                                          return const Text(
                                            'Loading practical review...',
                                          );
                                        }
                                        final data = review.data!.data();
                                        return Text(
                                          data == null
                                              ? 'Not yet reviewed'
                                              : '${data['status'] == 'validated' ? 'Validated by trainer' : 'Needs more practice'}\n${data['notes']}',
                                        );
                                      },
                                    ),
                                trailing: IconButton(
                                  tooltip: 'Review $competency',
                                  icon: const Icon(
                                    Icons.fact_check_outlined,
                                    color: Color(0xFF0369A1),
                                  ),
                                  onPressed: () => _review(
                                    doc.data()['studentId'].toString(),
                                    competency,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _AssessmentMetric extends StatelessWidget {
  const _AssessmentMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: Color(0xFFD7EAF1))),
      ],
    ),
  );
}

class _DiagnosticScore extends StatelessWidget {
  const _DiagnosticScore({required this.score, required this.total});
  final int score;
  final int total;
  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (score / total * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$score/$total · $percent%',
        style: const TextStyle(
          color: Color(0xFF287A46),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
