import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/quiz_model.dart';
import '../data/interactive_quizzes.dart';
import '../screens/student/module_view_page.dart';
import '../screens/student/take_quiz_page.dart';
import '../services/learning_path_service.dart';
import 'content_access_gate.dart';
import 'learning_flow_indicator.dart';

class ActivityPreparationGate extends StatefulWidget {
  final String classId, type, contentId, title;
  final Widget Function(bool practice) sessionBuilder;
  final Future<Map<String, dynamic>> Function()? stateLoader;
  final bool practiceOnly;
  const ActivityPreparationGate({
    super.key,
    required this.classId,
    required this.type,
    required this.contentId,
    required this.title,
    required this.sessionBuilder,
    this.stateLoader,
    this.practiceOnly = false,
  });
  @override
  State<ActivityPreparationGate> createState() =>
      _ActivityPreparationGateState();
}

class _ActivityPreparationGateState extends State<ActivityPreparationGate> {
  bool _starting = false;
  Future<void> _start(bool practice) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await LearningPathService.requirePrepared(
        widget.classId,
        widget.type,
        widget.contentId,
        practice: practice,
      );
      final user = FirebaseAuth.instance.currentUser!;
      FirebaseFirestore.instance
          .collection('activity_events')
          .add({
            'classId': widget.classId,
            'studentId': user.uid,
            'studentName': user.displayName ?? user.email ?? 'Student',
            'contentId': widget.contentId,
            'title': widget.title,
            'event': 'activity_opened',
            'mode': practice ? 'practice' : 'assessment',
            'createdAt': FieldValue.serverTimestamp(),
          })
          .then<void>(
            (_) {},
            onError: (Object error) {
              debugPrint('Could not record activity opening: $error');
            },
          );
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Activity not opened: $e')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  late Future<Map<String, dynamic>> _state;

  @override
  void initState() {
    super.initState();
    if (!widget.practiceOnly) _state = _refresh();
  }

  @override
  void didUpdateWidget(covariant ActivityPreparationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.practiceOnly && !widget.practiceOnly) {
      _state = _refresh();
    }
  }

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
    if (widget.type == 'quiz') {
      await LearningPathService.requireQuizAvailable(
        widget.classId,
        widget.contentId,
      );
      return {'configured': true};
    }
    if (widget.practiceOnly) {
      await LearningPathService.requireParticipant(widget.classId);
    } else {
      await LearningPathService.requireActive(widget.classId);
    }
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
        widget.practiceOnly ||
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
      final builtIn = InteractiveQuizzes.forClass(
        widget.classId,
      ).where((q) => q.id == path['quizId']).firstOrNull;
      if (builtIn != null && doc.data()?['isPublished'] != false) {
        quiz = builtIn;
      }
      if (doc.exists && doc.data()?['isPublished'] == true) {
        quiz ??= QuizModel.fromFirestore(doc);
      }
      theoryDone = await LearningPathService.hasCompletedQuiz(
        widget.classId,
        path['quizId'],
        firestore: db,
        studentId: uid,
      );
    }
    return {
      'configured':
          widget.type != 'simulation' ||
          (quiz != null &&
              (quiz.questions.isNotEmpty ||
                  InteractiveQuizzes.activity(widget.classId, quiz.id) !=
                      null)),
      'module': module.data()?['title'] ?? 'Required lesson',
      'learned': learned,
      'practiced': practiced,
      'theoryDone': theoryDone,
      'quiz': quiz,
    };
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() {
        _state = _refresh();
      });
    }
  }

  Widget _buildQuizReady(BuildContext context) {
    const accent = Color(0xFF6D5DFB);
    const deep = Color(0xFF35279A);
    const soft = Color(0xFFF1EEFF);

    return Container(
      color: const Color(0xFFF5F7FB),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [deep, accent],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.24),
                          blurRadius: 26,
                          offset: const Offset(0, 13),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -12,
                          top: -22,
                          child: Icon(
                            Icons.fact_check_rounded,
                            size: 132,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Text(
                                'KNOWLEDGE CHECK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.05,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.82, end: 1),
                                  duration: const Duration(milliseconds: 520),
                                  curve: Curves.easeOutBack,
                                  builder: (context, value, child) =>
                                      Transform.scale(
                                        scale: value,
                                        child: child,
                                      ),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(19),
                                    ),
                                    child: const Icon(
                                      Icons.quiz_rounded,
                                      color: accent,
                                      size: 34,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 17),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ready to take the quiz',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          height: 1.08,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        widget.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.84,
                                          ),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6EAF1)),
                    ),
                    child: const LearningFlowIndicator(
                      current: LearningFlowStage.quiz,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE6EAF1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF1E293B,
                          ).withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Before you begin',
                          style: TextStyle(
                            color: Color(0xFF172033),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 15),
                        _QuizRule(
                          icon: Icons.workspace_premium_rounded,
                          title: 'Scored assignment',
                          detail:
                              'Your final score will be recorded for grading.',
                        ),
                        SizedBox(height: 13),
                        _QuizRule(
                          icon: Icons.looks_one_rounded,
                          title: 'One recorded attempt',
                          detail: 'Review each response before you submit.',
                        ),
                        SizedBox(height: 13),
                        _QuizRule(
                          icon: Icons.save_rounded,
                          title: 'Submit to continue',
                          detail:
                              'Finish the quiz to unlock the assigned simulation.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_rounded, color: accent),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Read every question carefully. Your answers are saved only when the quiz is submitted successfully.',
                            style: TextStyle(
                              color: Color(0xFF4A4381),
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      onPressed: _starting ? null : () => _start(false),
                      icon: _starting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 26),
                      label: Text(
                        _starting
                            ? 'Preparing quiz...'
                            : 'Start scored quiz (one attempt)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationReady(Map<String, dynamic> state) {
    const accent = Color(0xFF0F9F8F);
    const deep = Color(0xFF075E57);
    const soft = Color(0xFFE7F8F4);
    final learned = state['learned'] == true;
    final practiced = state['practiced'] == true;
    final theoryDone = state['theoryDone'] == true;
    final quiz = state['quiz'] as QuizModel;
    final completed = [learned, practiced, theoryDone].where((v) => v).length;
    final ready = completed == 3;

    return Container(
      color: const Color(0xFFF4F8F7),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [deep, accent],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.23),
                          blurRadius: 26,
                          offset: const Offset(0, 13),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -12,
                          top: -22,
                          child: Icon(
                            Icons.precision_manufacturing_rounded,
                            size: 138,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Text(
                                'PRACTICAL ASSIGNMENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.05,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.82, end: 1),
                                  duration: const Duration(milliseconds: 520),
                                  curve: Curves.easeOutBack,
                                  builder: (context, value, child) =>
                                      Transform.scale(
                                        scale: value,
                                        child: child,
                                      ),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(19),
                                    ),
                                    child: const Icon(
                                      Icons.build_circle_rounded,
                                      color: accent,
                                      size: 35,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 17),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Learn first. Practice safely. Then demonstrate your skills.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                          height: 1.12,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        widget.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.84,
                                          ),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDDE9E6)),
                    ),
                    child: const LearningFlowIndicator(
                      current: LearningFlowStage.simulation,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFDDE9E6)),
                      boxShadow: [
                        BoxShadow(
                          color: deep.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preparation checklist',
                                    style: TextStyle(
                                      color: Color(0xFF172033),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Complete each step before the graded task.',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: soft,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$completed of 3 ready',
                                style: const TextStyle(
                                  color: deep,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _PreparationStep(
                          number: 1,
                          icon: Icons.menu_book_rounded,
                          title: 'Learn: ${state['module']}',
                          detail:
                              'Read or watch the linked module, then mark it complete.',
                          complete: learned,
                          available: true,
                          actionLabel: learned
                              ? 'Review lesson'
                              : 'Open lesson',
                          onTap: () => _open(
                            ModuleViewPage(
                              classId: widget.classId,
                              className: 'Required learning',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PreparationStep(
                          number: 2,
                          icon: Icons.sports_esports_rounded,
                          title: 'Required practice mode',
                          detail:
                              'Rehearse the procedure safely before your graded attempt.',
                          complete: practiced,
                          available: learned,
                          actionLabel: practiced
                              ? 'Practice completed'
                              : learned
                              ? 'Ready to practice'
                              : 'Complete the lesson first',
                        ),
                        const SizedBox(height: 12),
                        _PreparationStep(
                          number: 3,
                          icon: Icons.quiz_rounded,
                          title: 'Part A: terminology quiz',
                          detail:
                              '${quiz.title} - Check your understanding before the practical task.',
                          complete: theoryDone,
                          available: learned,
                          actionLabel: theoryDone
                              ? 'Quiz completed'
                              : learned
                              ? 'Open quiz'
                              : 'Complete the lesson first',
                          onTap: learned && !theoryDone
                              ? () => _open(
                                  TakeQuizPage(
                                    classId: widget.classId,
                                    quiz: quiz,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final practiceButton = OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: deep,
                          side: const BorderSide(color: accent, width: 1.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.sports_esports_rounded),
                        onPressed: learned && !_starting
                            ? () => _start(true)
                            : null,
                        label: Text(
                          practiced ? 'Practice again' : 'Start practice mode',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                      final assessmentButton = FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.assignment_turned_in_rounded),
                        onPressed: ready && !_starting
                            ? () => _start(false)
                            : null,
                        label: const Text(
                          'Part B: start graded simulation assignment',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                      if (widget.practiceOnly) return practiceButton;
                      if (constraints.maxWidth < 620) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            practiceButton,
                            const SizedBox(height: 12),
                            assessmentButton,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: practiceButton),
                          const SizedBox(width: 12),
                          Expanded(child: assessmentButton),
                        ],
                      );
                    },
                  ),
                  if (!ready) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF8D99A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lock_clock_rounded,
                            color: Color(0xFF9A6100),
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'The graded simulation unlocks after the lesson, practice, and quiz are complete.',
                              style: TextStyle(
                                color: Color(0xFF7A4C00),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeOnly() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF075E57), Color(0xFF0F9F8F)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F9F8F).withValues(alpha: .24),
                blurRadius: 26,
                offset: const Offset(0, 13),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.precision_manufacturing_rounded,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Review and repeat the complete hands-on procedure at your own pace.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _starting ? null : () => _start(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF075E57),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    _starting ? 'Opening practice...' : 'Start practice',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: widget.practiceOnly
        ? _buildPracticeOnly()
        : FutureBuilder<Map<String, dynamic>>(
            future: _state,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
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
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final state = snapshot.data!;
              if (state['configured'] != true) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This activity is waiting for teacher setup. Your teacher or trainer must publish a lesson, publish a theory quiz with questions for simulations, and link them in Modules > Lesson & assignment links. Uploading a draft alone does not unlock the activity.',
                    ),
                  ),
                );
              }
              if (widget.type == 'quiz') {
                return _buildQuizReady(context);
              }
              return _buildSimulationReady(state);
            },
          ),
  );
}

class _PreparationStep extends StatelessWidget {
  const _PreparationStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    required this.complete,
    required this.available,
    required this.actionLabel,
    this.onTap,
  });

  final int number;
  final IconData icon;
  final String title;
  final String detail;
  final bool complete;
  final bool available;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0F9F8F);
    final active = complete || available;
    return Material(
      color: complete
          ? const Color(0xFFE7F8F4)
          : active
          ? const Color(0xFFF8FBFA)
          : const Color(0xFFF4F5F7),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: complete
                  ? accent.withValues(alpha: 0.28)
                  : const Color(0xFFE1E7E5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: complete
                      ? accent
                      : active
                      ? Colors.white
                      : const Color(0xFFE4E7EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  complete ? Icons.check_rounded : icon,
                  color: complete
                      ? Colors.white
                      : active
                      ? accent
                      : const Color(0xFF98A2B3),
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$number. $title',
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF172033)
                            : const Color(0xFF667085),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: active ? accent : const Color(0xFF98A2B3),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: accent,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizRule extends StatelessWidget {
  const _QuizRule({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF1EEFF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: const Color(0xFF6D5DFB), size: 22),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
