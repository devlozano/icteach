import '../../widgets/system_survey_flow.dart';
import '../../services/feedback_eligibility.dart';
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
  bool loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await FeedbackEligibility.requireQualified();
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

  Future<void> _save(Map<int, int> answers, String suggestion) async {
    await FeedbackEligibility.requireQualified();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('app_helpfulness_surveys')
        .doc(uid)
        .set({
          'studentId': uid,
          'version': 1,
          'ratings': {
            for (final entry in answers.entries) 'q${entry.key}': entry.value,
          },
          'comment': suggestion,
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
    return SystemSurveyFlow(
      initialRatings: ratings,
      initialComment: comment.text,
      onSave: _save,
    );
  }
}
