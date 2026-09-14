import '../../services/feedback_eligibility.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/learning_path_service.dart';

class CourseFeedbackPage extends StatefulWidget {
  final String classId;
  final bool systemEvaluation;
  const CourseFeedbackPage({
    super.key,
    required this.classId,
    this.systemEvaluation = true,
  });
  @override
  State<CourseFeedbackPage> createState() => _CourseFeedbackPageState();
}

class _CourseFeedbackPageState extends State<CourseFeedbackPage> {
  final _comment = TextEditingController();
  final _ratings = <int, int>{};
  bool _saving = false;
  late final Future<bool> _ready = _checkLessons();
  List<String> get _prompts => widget.systemEvaluation
      ? [
          'How easy is ICTeach to use? (1 very difficult – 5 very easy)',
          'How useful are the lessons and simulations? (1 not useful – 5 very useful)',
          'How reliable was the app? (1 frequent problems – 5 no problems)',
        ]
      : [
          'How clearly does your teacher explain the lessons? (1 unclear – 5 very clear)',
          'How difficult are the lessons/practical activities? (1 easy – 5 very difficult)',
          'How helpful are demonstrations and feedback? (1 not helpful – 5 very helpful)',
        ];
  Future<bool> _checkLessons() async {
    await LearningPathService.requireActive(widget.classId);
    if (!widget.systemEvaluation) return true;
    await FeedbackEligibility.requireQualified();
    return true;
  }

  Future<void> _save() async {
    if (_ratings.length != _prompts.length ||
        _comment.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Answer every rating and enter at least 10 characters of feedback.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (!await _checkLessons())
        throw StateError('NC II qualification must be recorded first.');
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser!;
      final type = widget.systemEvaluation
          ? 'system_evaluation'
          : 'teaching_feedback';
      final teacher = (await db.collection('classes').doc(widget.classId).get())
          .data();
      final profile = (await db.collection('users').doc(user.uid).get()).data();
      await db
          .collection('questionnaire_responses')
          .doc('${type}_${widget.classId}_${user.uid}')
          .set({
            'classId': widget.classId,
            'questionnaireId': '${type}_${widget.classId}',
            'questionnaireTitle': widget.systemEvaluation
                ? 'End-of-lessons ICTeach evaluation'
                : 'Teaching & learning difficulty check-in',
            'questionnaireType': type,
            'studentId': user.uid,
            'studentName': profile?['name'] ?? user.email ?? 'Student',
            'teacherId': teacher?['teacherId'],
            'teacherName': teacher?['teacherName'],
            'ratings': {
              for (final e in _ratings.entries) 'rating_${e.key + 1}': e.value,
            },
            'ratingPrompts': {
              for (var i = 0; i < _prompts.length; i++)
                'rating_${i + 1}': _prompts[i],
            },
            'writtenAnswers': {'comment': _comment.text.trim()},
            'summary': _comment.text.trim(),
            'submittedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Feedback saved. Your teacher/trainer can review it in Class Insights.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Feedback not saved: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.systemEvaluation
            ? 'Evaluate ICTeach'
            : 'Teaching & learning check-in',
      ),
    ),
    body: FutureBuilder<bool>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text(
              'Unable to verify lessons. Reopen this page when connected.',
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data != true)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'System feedback is available in Profile after your NC II qualification is recorded.',
              ),
            ),
          );
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Responses are identified, not anonymous. Your class teacher/trainer can review them to improve teaching and the system. Submitting again updates your response.',
            ),
            for (var i = 0; i < _prompts.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_prompts[i]),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var value = 1; value <= 5; value++)
                          ChoiceChip(
                            label: Text('$value'),
                            selected: _ratings[i] == value,
                            onSelected: _saving
                                ? null
                                : (_) => setState(() => _ratings[i] = value),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _comment,
              enabled: !_saving,
              maxLength: 1500,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: widget.systemEvaluation
                    ? 'Problems experienced and suggestions for improvement'
                    : 'Which topic was difficult, and how could your teacher explain it better?',
              ),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Submit feedback'),
            ),
          ],
        );
      },
    ),
  );
}
