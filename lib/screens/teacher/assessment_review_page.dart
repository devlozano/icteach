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
    appBar: AppBar(
      title: Text('Assessments - ${widget.className}'),
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
                Text(
                  '${records.length} completed diagnostics',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Diagnostic scores guide instruction. Record practical validation only after observing the learner.',
                ),
                const SizedBox(height: 16),
                for (final doc in records)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.data()['studentName']?.toString() ?? 'Student',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Diagnostic: ${doc.data()['score']}/${doc.data()['totalQuestions']}',
                          ),
                          for (final competency in ['COC1', 'COC2'])
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '$competency: ${(doc.data()['competencyScores'] as Map?)?[competency] ?? 0}/6 correct',
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
                                icon: const Icon(Icons.fact_check_outlined),
                                onPressed: () => _review(
                                  doc.data()['studentId'].toString(),
                                  competency,
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
