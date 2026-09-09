import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/pre_assessment_data.dart';
import '../../services/content_access_service.dart';

class PreAssessmentPage extends StatefulWidget {
  final String classId;
  final String className;
  final WidgetBuilder builder;
  const PreAssessmentPage({
    super.key,
    required this.classId,
    required this.className,
    required this.builder,
  });
  @override
  State<PreAssessmentPage> createState() => _PreAssessmentPageState();
}

class _PreAssessmentPageState extends State<PreAssessmentPage> {
  late Future<bool> _access;
  final _answers = List<int?>.filled(PreAssessmentData.questions.length, null);
  bool _saving = false;
  bool _started = false;
  bool _continue = false;
  Map<String, dynamic>? _result;
  @override
  void initState() {
    super.initState();
    _access = _check();
  }

  @override
  void didUpdateWidget(covariant PreAssessmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _answers.fillRange(0, _answers.length, null);
      _result = null;
      _continue = false;
      _started = false;
      _access = _check();
    }
  }

  Future<bool> _check() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in first.');
    if (await ContentAccessService.isClassStaff(widget.classId)) return true;
    final doc = await FirebaseFirestore.instance
        .collection('pre_assessments')
        .doc('${uid}_${widget.classId}')
        .get();
    return PreAssessmentData.isComplete(doc.data());
  }

  Future<void> _submit() async {
    if (_saving || _answers.any((a) => a == null)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Please sign in first.');
      final answers = _answers.cast<int>();
      final result = PreAssessmentData.score(answers);
      final ref = FirebaseFirestore.instance
          .collection('pre_assessments')
          .doc('${user.uid}_${widget.classId}');
      final saved = await FirebaseFirestore.instance
          .runTransaction<Map<String, dynamic>>((transaction) async {
            final previous = await transaction.get(ref);
            if (PreAssessmentData.isComplete(previous.data())) {
              return previous.data()!;
            }
            final data = {
              ...result,
              'answers': answers,
              'version': PreAssessmentData.version,
              'completed': true,
              'studentId': user.uid,
              'studentName': user.displayName ?? user.email ?? 'Student',
              'classId': widget.classId,
              'completedAt': FieldValue.serverTimestamp(),
            };
            transaction.set(ref, data);
            return data;
          });
      if (mounted) setState(() => _result = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Assessment not saved. Reconnect and try again; your answers are still here.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _submittedAnswerText(int questionIndex) {
    final answers = _result?['answers'];
    final options = PreAssessmentData.questions[questionIndex].options;
    if (answers is! List || questionIndex >= answers.length) {
      return 'Not recorded';
    }
    final answer = answers[questionIndex];
    if (answer is! int || answer < 0 || answer >= options.length) {
      return 'Not recorded';
    }
    return options[answer];
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, access) {
      if (access.data == true || _continue) return widget.builder(context);
      return Scaffold(
        appBar: AppBar(title: Text('Pre-assessment - ${widget.className}')),
        body: access.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator())
            : access.hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to check pre-assessment access.'),
                    TextButton(
                      onPressed: () => setState(() => _access = _check()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'CSS readiness diagnostic',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Answer all 12 questions before opening learning modules. Your trainer uses the results to identify topics needing support. Any score unlocks modules; this is not a certification exam.',
                      ),
                      const SizedBox(height: 20),
                      if (_result != null) ...[
                        Text(
                          'Saved: ${_result!['score']} / ${_result!['totalQuestions']} correct',
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 12),
                        for (
                          var i = 0;
                          i < PreAssessmentData.questions.length;
                          i++
                        )
                          ListTile(
                            title: Text(PreAssessmentData.questions[i].prompt),
                            subtitle: Text(
                              'Your answer: ${_submittedAnswerText(i)}\n'
                              'Correct answer: ${PreAssessmentData.questions[i].options[PreAssessmentData.questions[i].answer]}',
                            ),
                          ),
                        FilledButton(
                          onPressed: () => setState(() => _continue = true),
                          child: const Text('Continue to modules'),
                        ),
                      ] else if (!_started)
                        FilledButton(
                          onPressed: () => setState(() => _started = true),
                          child: const Text('Start pre-assessment'),
                        )
                      else ...[
                        for (
                          var i = 0;
                          i < PreAssessmentData.questions.length;
                          i++
                        )
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${i + 1}. ${PreAssessmentData.questions[i].prompt}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (
                                    var j = 0;
                                    j <
                                        PreAssessmentData
                                            .questions[i]
                                            .options
                                            .length;
                                    j++
                                  )
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        _answers[i] == j
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                      ),
                                      title: Text(
                                        PreAssessmentData
                                            .questions[i]
                                            .options[j],
                                      ),
                                      onTap: _saving
                                          ? null
                                          : () =>
                                                setState(() => _answers[i] = j),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        Text(
                          '${_answers.whereType<int>().length} of ${_answers.length} answered',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving || _answers.any((a) => a == null)
                              ? null
                              : _submit,
                          child: Text(
                            _saving
                                ? 'Saving assessment...'
                                : 'Submit assessment',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
