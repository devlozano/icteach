import '../../services/assessment_order.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/quiz_model.dart';
import '../../services/quiz_service.dart';
import '../../widgets/content_access_gate.dart';
import '../../widgets/activity_preparation_gate.dart';
import '../../services/learning_path_service.dart';
import 'quiz_results_page.dart'; // ✅ ADD THIS IMPORT

class TakeQuizPage extends StatelessWidget {
  final String classId;
  final QuizModel quiz;
  const TakeQuizPage({super.key, required this.classId, required this.quiz});
  @override
  Widget build(BuildContext context) => ContentAccessGate(
    classId: classId,
    contentType: 'quiz',
    contentId: quiz.id,
    builder: (_) => ActivityPreparationGate(
      classId: classId,
      type: 'quiz',
      contentId: quiz.id,
      title: quiz.title,
      sessionBuilder: (practice) =>
          _QuizSession(classId: classId, quiz: quiz, practice: practice),
    ),
  );
}

class _QuizSession extends StatefulWidget {
  final bool practice;
  final String classId;
  final QuizModel quiz;

  const _QuizSession({
    required this.classId,
    required this.quiz,
    required this.practice,
  });

  @override
  State<_QuizSession> createState() => _TakeQuizPageState();
}

class _TakeQuizPageState extends State<_QuizSession> {
  final QuizService _quizService = QuizService();
  List<int?> _selectedAnswers = [];
  late final AssessmentOrder _order;
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;
  Timer? _timer;
  int _timeRemaining = 0;
  int _timeSpent = 0;

  @override
  void initState() {
    super.initState();
    _order = AssessmentOrder(
      widget.quiz.questions.map((q) => q.options.length).toList(),
    );
    _selectedAnswers = List.filled(widget.quiz.questions.length, null);
    if (!widget.practice && widget.quiz.timeLimit > 0) {
      _timeRemaining = widget.quiz.timeLimit * 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _timeRemaining--;
          _timeSpent++;
          if (_timeRemaining <= 0) {
            _submitQuiz();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _submitQuiz() async {
    if (_isSubmitting) return;
    _timer?.cancel();
    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit quiz')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      // Calculate results
      int correctCount = 0;
      final userAnswers = <UserAnswer>[];

      for (int i = 0; i < widget.quiz.questions.length; i++) {
        final question = widget.quiz.questions[i];
        final selected = _selectedAnswers[i];
        final isCorrect = selected == question.correctAnswer;

        if (isCorrect) correctCount += question.points;

        userAnswers.add(
          UserAnswer(
            questionId: question.id,
            selectedAnswer: selected ?? -1,
            isCorrect: isCorrect,
            correctAnswerText: question.options[question.correctAnswer],
            explanation: question.explanation,
          ),
        );
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final studentName =
          userDoc.data()?['name'] ?? user.displayName ?? 'Student';

      final result = QuizResult(
        quizId: widget.quiz.id,
        classId: widget.classId, // ✅ ADDED
        studentId: user.uid,
        studentName: studentName,
        score: correctCount,
        totalPoints: widget.quiz.questions.fold<int>(
          0,
          (total, q) => total + q.points,
        ),
        userAnswers: userAnswers,
        completedAt: DateTime.now(),
        timeSpent: _timeSpent,
      );

      await LearningPathService.requirePrepared(
        widget.classId,
        'quiz',
        widget.quiz.id,
        practice: widget.practice,
      );
      if (widget.practice) {
        await LearningPathService.savePractice(
          widget.classId,
          'quiz',
          widget.quiz.id,
          widget.quiz.title,
          correctCount,
          result.totalPoints,
        );
      } else {
        await _quizService.saveQuizResult(result);
      }

      if (!mounted) return;

      // ✅ Navigate to QuizResultsPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizResultsPage(
            result: result,
            questions: widget.quiz.questions,
            quizTitle: widget.practice
                ? 'PRACTICE (ungraded): ${widget.quiz.title}'
                : widget.quiz.title,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Result not saved: $error. Your answers are retained; retry submitting.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quiz.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: const Center(child: Text('This quiz has no questions yet.')),
      );
    }
    final originalIndex = _order.questions[_currentQuestionIndex];
    final question = widget.quiz.questions[originalIndex];
    final progress =
        ((_currentQuestionIndex + 1) / widget.quiz.questions.length * 100);

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.practice
              ? 'Practice (ungraded): ${widget.quiz.title}'
              : widget.quiz.title,
        ),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!widget.practice && widget.quiz.timeLimit > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeRemaining < 60 ? Colors.red : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_timeRemaining),
                      style: TextStyle(
                        color: _timeRemaining < 60 ? Colors.red : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            height: 4,
            color: Colors.grey.shade300,
            child: FractionallySizedBox(
              widthFactor: progress / 100,
              child: Container(color: const Color(0xFF0B2B4A)),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question counter
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${widget.quiz.questions.length}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),

                  // Question text
                  Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ..._order.options[originalIndex].asMap().entries.map((entry) {
                    final index = entry.value;
                    final option = question.options[index];
                    final isSelected = _selectedAnswers[originalIndex] == index;

                    return GestureDetector(
                      onTap:
                          _isSubmitting ||
                              (!widget.practice &&
                                  widget.quiz.timeLimit > 0 &&
                                  _timeRemaining <= 0)
                          ? null
                          : () {
                              setState(() {
                                _selectedAnswers[originalIndex] = index;
                              });
                            },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0B2B4A).withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0B2B4A)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? const Color(0xFF0B2B4A)
                                    : Colors.grey.shade300,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + entry.key),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF0B2B4A),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Navigation buttons
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentQuestionIndex--;
                              });
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Previous'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      if (_currentQuestionIndex <
                          widget.quiz.questions.length - 1) ...[
                        if (_currentQuestionIndex > 0)
                          const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentQuestionIndex++;
                              });
                            },
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B2B4A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (_currentQuestionIndex ==
                      widget.quiz.questions.length - 1) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitQuiz,
                        icon: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit Quiz',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Progress dots
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(widget.quiz.questions.length, (
                      index,
                    ) {
                      final isAnswered =
                          _selectedAnswers[_order.questions[index]] != null;
                      final isCurrent = index == _currentQuestionIndex;
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAnswered
                              ? const Color(0xFF0B2B4A)
                              : isCurrent
                              ? Colors.grey.shade500
                              : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
