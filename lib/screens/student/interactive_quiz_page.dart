import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/interactive_quizzes.dart';
import '../../data/guided_setup_data.dart';
import '../../models/quiz_model.dart';
import '../../models/simulation_model.dart' as models;
import '../../services/quiz_service.dart';
import '../../widgets/activity_preparation_gate.dart';
import '../../widgets/content_access_gate.dart';
import '../../widgets/guided_setup_workbench.dart';
import '../../widgets/motherboard_identification.dart';
import '../../widgets/simulation_step_lab.dart';
import 'learning_continuation_page.dart';

class InteractiveQuizPage extends StatelessWidget {
  const InteractiveQuizPage({super.key, required this.quiz});
  final QuizModel quiz;
  @override
  Widget build(BuildContext context) => ContentAccessGate(
    classId: quiz.classId,
    contentType: 'quiz',
    contentId: quiz.id,
    builder: (_) => ActivityPreparationGate(
      classId: quiz.classId,
      type: 'quiz',
      contentId: quiz.id,
      title: quiz.title,
      sessionBuilder: (_) => _Session(quiz: quiz),
    ),
  );
}

class _Session extends StatefulWidget {
  const _Session({required this.quiz});
  final QuizModel quiz;
  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  final _watch = Stopwatch()..start();
  bool _saved = false, _saving = false, _allowExit = false, _confirming = false;
  int? _score, _total;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void dispose() {
    _watch.stop();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sign in again to save your quiz.');
      await QuizService().saveQuizResult(
        QuizResult(
          passingPercentage: 80,
          quizId: widget.quiz.id,
          classId: widget.quiz.classId,
          studentId: user.uid,
          studentName: user.displayName ?? user.email ?? 'Student',
          score: _score!,
          totalPoints: _total!,
          userAnswers: const [],
          completedAt: DateTime.now(),
          timeSpent: _watch.elapsed.inSeconds,
        ),
      );
      if (mounted) setState(() => _saved = true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Your result has not been saved. $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exit() async {
    if (_confirming || _saving) return;
    _confirming = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this quiz?'),
        content: const Text(
          'Your unfinished attempt will not be saved. Stay to complete the procedure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave quiz'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (exit == true && mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _saved || _allowExit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quiz.title,
          maxLines: 2,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _score != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Icon(Icons.fact_check_outlined, size: 48),
                      Text(
                        'Quiz complete: $_score / $_total',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_saving) const LinearProgressIndicator(),
                      if (_saved)
                        FilledButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LearningContinuationPage(
                                classId: widget.quiz.classId,
                                quizId: widget.quiz.id,
                              ),
                            ),
                          ),
                          child: const Text('Continue to simulation'),
                        ),
                      if (_saved)
                        const Text(
                          'Saved to your quiz results.',
                          textAlign: TextAlign.center,
                        ),
                      if (_error != null) ...[
                        Text(_error!),
                        FilledButton(
                          onPressed: _save,
                          child: const Text('Retry saving result'),
                        ),
                      ],
                      if (_saved)
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back to quizzes'),
                        ),
                    ],
                  )
                : InteractiveQuizWorkbench(
                    activity: InteractiveQuizzes.activity(
                      widget.quiz.classId,
                      widget.quiz.id,
                    )!,
                    onComplete: (score, total, passed) {
                      _watch.stop();
                      setState(() {
                        _score = score;
                        _total = total;
                      });
                      _save();
                    },
                  ),
          ),
        ),
      ),
    ),
  );
}

/// Portrait-first workbench shared by the scored session and layout tests.
class InteractiveQuizWorkbench extends StatefulWidget {
  const InteractiveQuizWorkbench({
    super.key,
    required this.activity,
    required this.onComplete,
  });
  final models.Simulation activity;
  final void Function(int, int, bool) onComplete;
  @override
  State<InteractiveQuizWorkbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<InteractiveQuizWorkbench> {
  int _step = 0, _mistakes = 0;
  bool _complete = false;

  String get _phase {
    final count = widget.activity.items.where((item) => item.isRequired).length;
    if (_step == 0) return 'Prepare and inspect';
    if (_step >= count - 1) return 'Verify and record';
    return 'Perform the procedure';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activity.id == 'sim_coc1_motherboard') {
      return MotherboardIdentification(onComplete: widget.onComplete);
    }
    final kind = GuidedSetupData.kindForId(widget.activity.id);
    if (kind != null) {
      return GuidedSetupWorkbench(
        kind: kind,
        quiz: true,
        onComplete: widget.onComplete,
      );
    }
    final items = widget.activity.items
        .where((item) => item.isRequired)
        .toList();
    if (_complete) return const Center(child: Text('Procedure complete'));
    final progress = (_step + 1) / items.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B4F6C), Color(0xFF168AAD)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260B4F6C),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.engineering_outlined, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.activity.learningOutcome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Task ${_step + 1} of ${items.length}  |  $_phase',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFFB8F2E6),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Read the work order, perform each action in sequence, then decide whether the observed result passes.',
                  style: TextStyle(color: Color(0xFFE7F7FC), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SimulationStepLab(
            key: ValueKey(items[_step].id),
            simulation: widget.activity,
            item: items[_step],
            onMistake: (_) => _mistakes++,
            onComplete: () {
              if (_step + 1 == items.length) {
                setState(() => _complete = true);
                final score = (items.length - _mistakes).clamp(0, items.length);
                widget.onComplete(
                  score,
                  items.length,
                  score / items.length >= .8,
                );
              } else {
                setState(() => _step++);
              }
            },
          ),
        ),
      ],
    );
  }
}
