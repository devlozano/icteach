import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/quiz_model.dart';
import '../screens/student/module_view_page.dart';
import '../screens/student/take_quiz_page.dart';
import '../services/learning_path_service.dart';
import 'content_access_gate.dart';

class ActivityPreparationGate extends StatefulWidget {
  final String classId, type, contentId, title;
  final Widget Function(bool practice) sessionBuilder;
  final Future<Map<String, dynamic>> Function()? stateLoader;
  const ActivityPreparationGate({
    super.key,
    required this.classId,
    required this.type,
    required this.contentId,
    required this.title,
    required this.sessionBuilder,
    this.stateLoader,
  });
  @override
  State<ActivityPreparationGate> createState() =>
      _ActivityPreparationGateState();
}

class _ActivityPreparationGateState extends State<ActivityPreparationGate> {
  bool _starting = false;
  Future<void> _start(bool practice) async {
    if (_starting) return;
    _starting = true;
    try {
      await LearningPathService.requirePrepared(
        widget.classId,
        widget.type,
        widget.contentId,
        practice: practice,
      );
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('activity_events').add({
        'classId': widget.classId,
        'studentId': user.uid,
        'studentName': user.displayName ?? user.email ?? 'Student',
        'contentId': widget.contentId,
        'title': widget.title,
        'event': 'activity_opened',
        'mode': practice ? 'practice' : 'assessment',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await _open(
        ContentAccessGate(
          classId: widget.classId,
          contentType: widget.type,
          contentId: widget.contentId,
          builder: (_) => widget.sessionBuilder(practice),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Activity not opened: $e')));
    } finally {
      _starting = false;
    }
  }

  late Future<Map<String, dynamic>> _state = _refresh();
  Future<Map<String, dynamic>> _refresh() {
    final future = Future<Map<String, dynamic>>.sync(
      () => widget.stateLoader?.call() ?? _load(),
    );
    // A retry can finish before the next frame attaches FutureBuilder.
    // Keep the error on the original future for its error UI, while observing it now.
    future.ignore();
    return future;
  }

  Future<Map<String, dynamic>> _load() async {
    await LearningPathService.requireActive(widget.classId);
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final root = db.collection('classes').doc(widget.classId);
    final path =
        (await root
                .collection('learning_paths')
                .doc(LearningPathService.key(widget.type, widget.contentId))
                .get())
            .data();
    if (path == null || path['moduleId'] == null) return {'configured': false};
    final module = await root.collection('modules').doc(path['moduleId']).get();
    if (module.data()?['isPublished'] != true) return {'configured': false};
    final user = db.collection('users').doc(uid);
    final learned =
        (await user
                .collection('module_progress')
                .doc('${widget.classId}_${path['moduleId']}')
                .get())
            .data()?['completed'] ==
        true;
    final practiced =
        (await user
                .collection('practice_progress')
                .doc(
                  '${widget.classId}_${LearningPathService.key(widget.type, widget.contentId)}',
                )
                .get())
            .data()?['completed'] ==
        true;
    QuizModel? quiz;
    var theoryDone = widget.type != 'simulation';
    if (widget.type == 'simulation' && path['quizId'] != null) {
      final doc = await root.collection('quizzes').doc(path['quizId']).get();
      if (doc.exists && doc.data()?['isPublished'] == true)
        quiz = QuizModel.fromFirestore(doc);
      final result =
          (await user.collection('quiz_results').doc(path['quizId']).get())
              .data();
      theoryDone = result != null && result['classId'] == widget.classId;
    }
    return {
      'configured':
          widget.type != 'simulation' ||
          (quiz != null && quiz.questions.isNotEmpty),
      'module': module.data()?['title'] ?? 'Required lesson',
      'learned': learned,
      'practiced': practiced,
      'theoryDone': theoryDone,
      'quiz': quiz,
    };
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted)
      setState(() {
        _state = _refresh();
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _state,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Unable to prepare activity: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _state = _refresh();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final state = snapshot.data!;
        if (state['configured'] != true)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This activity is waiting for teacher setup. Your teacher or trainer must publish a lesson, publish a theory quiz with questions for simulations, and link them in Modules > Lesson & assessment links. Uploading a draft alone does not unlock the activity.',
              ),
            ),
          );
        final learned = state['learned'] == true;
        final practiced = state['practiced'] == true;
        final theoryDone = state['theoryDone'] == true;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Learn first. Practice safely. Then demonstrate your skills.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: Icon(learned ? Icons.check_circle : Icons.menu_book),
              title: Text('1. Learn: ${state['module']}'),
              subtitle: const Text(
                'Read/watch the linked module and mark it complete.',
              ),
              onTap: () => _open(
                ModuleViewPage(
                  classId: widget.classId,
                  className: 'Required learning',
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                practiced ? Icons.check_circle : Icons.sports_esports,
              ),
              title: const Text('2. Practice (ungraded)'),
              subtitle: const Text(
                'Repeat freely. Practice never changes grades or leaderboard scores.',
              ),
              enabled: learned,
              onTap: learned ? () => _start(true) : null,
            ),
            if (widget.type == 'simulation')
              ListTile(
                leading: Icon(theoryDone ? Icons.check_circle : Icons.quiz),
                title: const Text('3. Part 1: theory / terminology quiz'),
                subtitle: Text((state['quiz'] as QuizModel).title),
                enabled: learned && !theoryDone,
                onTap: learned && !theoryDone
                    ? () => _open(
                        TakeQuizPage(
                          classId: widget.classId,
                          quiz: state['quiz'] as QuizModel,
                        ),
                      )
                    : null,
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.assignment_turned_in),
              onPressed: learned && practiced && theoryDone
                  ? () => _start(false)
                  : null,
              label: Text(
                widget.type == 'simulation'
                    ? 'Part 2: interactive simulation assessment'
                    : 'Start scored quiz (one attempt)',
              ),
            ),
          ],
        );
      },
    ),
  );
}
