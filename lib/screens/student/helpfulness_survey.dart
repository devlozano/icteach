import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/student_outcomes.dart';

class HelpfulnessSurvey extends StatefulWidget {
  const HelpfulnessSurvey({super.key});
  @override
  State<HelpfulnessSurvey> createState() => _HelpfulnessSurveyState();
}

class _HelpfulnessSurveyState extends State<HelpfulnessSurvey> {
  final ratings = <int, int>{};
  final comment = TextEditingController();
  bool saving = false;
  bool loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          (await FirebaseFirestore.instance
                  .collection('app_helpfulness_surveys')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .get())
              .data();
      if (!mounted) return;
      final old = data?['ratings'] as Map? ?? {};
      for (var i = 0; i < helpfulnessPrompts.length; i++) {
        final value = old['q$i'];
        if (value is int && value >= 1 && value <= 5) ratings[i] = value;
      }
      comment.text = data?['comment']?.toString() ?? '';
      setState(() {
        loaded = true;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load your survey. Tap to retry.');
      }
    }
  }

  Future<void> _save() async {
    if (ratings.length != helpfulnessPrompts.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all four questions.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('app_helpfulness_surveys')
          .doc(uid)
          .set({
            'studentId': uid,
            'version': 1,
            'ratings': {for (final e in ratings.entries) 'q${e.key}': e.value},
            'comment': comment.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been saved.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save feedback. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: Text(error!)),
      );
    }
    if (!loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Does ICTeach help you learn?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your answers help us improve ICTeach. Staff can review your feedback. You can update your response at any time.',
        ),
        const SizedBox(height: 16),
        const Text(
          '1 = Strongly disagree   •   3 = Neutral   •   5 = Strongly agree',
        ),
        for (var i = 0; i < helpfulnessPrompts.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    helpfulnessPrompts[i],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (var score = 1; score <= 5; score++)
                        ChoiceChip(
                          label: Text('$score'),
                          selected: ratings[i] == score,
                          onSelected: saving
                              ? null
                              : (_) => setState(() => ratings[i] = score),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        TextField(
          controller: comment,
          enabled: !saving,
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What helps you? What could be improved? (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: const Icon(Icons.send_outlined),
          label: Text(saving ? 'Saving…' : 'Save feedback'),
        ),
      ],
    );
  }
}
