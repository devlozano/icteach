import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/quiz_model.dart';
import '../../services/quiz_service.dart';
import 'take_quiz_page.dart';
import 'quiz_results_page.dart';
import '../../widgets/motherboard_identification.dart';

class StudentQuizzesPage extends StatefulWidget {
  final String classId;
  final String className;

  const StudentQuizzesPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<StudentQuizzesPage> createState() => _StudentQuizzesPageState();
}

class _StudentQuizzesPageState extends State<StudentQuizzesPage> {
  final QuizService _quizService = QuizService();
  late Stream<List<QuizModel>> _quizzes;
  @override
  void initState() {
    super.initState();
    _watchQuizzes();
  }

  void _watchQuizzes() {
    _quizzes = _quizService.getPublishedQuizzesForClass(widget.classId);
  }

  @override
  void didUpdateWidget(covariant StudentQuizzesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) _watchQuizzes();
  }

  Future<void> _takeQuiz(QuizModel quiz) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to take quizzes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if student has already taken the quiz
    try {
      final hasTaken = await _quizService.hasTakenQuiz(user.uid, quiz.id);
      if (!mounted) return;
      if (hasTaken) {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Already Taken'),
            content: const Text(
              'You have already completed this quiz. You can view your results.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'view'),
                child: const Text('View Results'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (action == 'view') {
          // Fetch and show existing results
          final results = await _quizService.getStudentQuizResults(user.uid);
          final result = results.firstWhere((r) => r.quizId == quiz.id);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizResultsPage(
                result: result,
                questions: quiz.questions,
                quizTitle: quiz.title,
              ),
            ),
          );
          return;
        } else {
          return;
        }
      }
    } catch (e) {
      print('Error checking quiz status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to verify your quiz attempt. Reconnect and try again.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakeQuizPage(classId: widget.classId, quiz: quiz),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        appBar: AppBar(
          title: const Text('Quizzes'),
          backgroundColor: const Color(0xFF428DEB),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please sign in to view quizzes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text('Quizzes'),
        backgroundColor: const Color(0xFF428DEB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<QuizModel>>(
        stream: _quizzes,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }

          final quizzes = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quizzes.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _MotherboardQuizCard(
                  onOpen: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MotherboardIdentificationQuizPage(),
                    ),
                  ),
                );
              }
              final quiz = quizzes[index - 1];
              return _QuizCard(
                key: ValueKey(quiz.id),
                quiz: quiz,
                onTakeQuiz: () => _takeQuiz(quiz),
                userId: user.uid,
                quizService: _quizService,
              );
            },
          );
        },
      ),
    );
  }
}

class _MotherboardQuizCard extends StatelessWidget {
  const _MotherboardQuizCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFBFDBFE)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFDBEAFE),
              child: Icon(Icons.memory_rounded, color: Color(0xFF1D4ED8)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motherboard Parts Identification',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Built-in visual quiz • Portrait orientation',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Locate sockets, slots, power connectors, ports, and the chipset on an actual motherboard image.',
          style: TextStyle(color: Color(0xFF475569), height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Take identification quiz'),
          ),
        ),
      ],
    ),
  );
}

class MotherboardIdentificationQuizPage extends StatefulWidget {
  const MotherboardIdentificationQuizPage({super.key});

  @override
  State<MotherboardIdentificationQuizPage> createState() =>
      _MotherboardIdentificationQuizPageState();
}

class _MotherboardIdentificationQuizPageState
    extends State<MotherboardIdentificationQuizPage> {
  String? _result;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('Motherboard Identification Quiz'),
      backgroundColor: const Color(0xFF0B2B4A),
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              if (_result != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFFE0F2FE),
                  child: Text(
                    _result!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Expanded(
                child: MotherboardIdentification(
                  onComplete: (score, total, passed) => setState(() {
                    _result =
                        'Quiz complete: $score/$total • ${passed ? "Passed" : "Review and try again"}';
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ✅ Enhanced Quiz Card with Status Badge
class _QuizCard extends StatefulWidget {
  final QuizModel quiz;
  final VoidCallback onTakeQuiz;
  final String userId;
  final QuizService quizService;

  const _QuizCard({
    super.key,
    required this.quiz,
    required this.onTakeQuiz,
    required this.userId,
    required this.quizService,
  });

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  bool? _hasTaken;
  QuizResult? _result;

  @override
  void initState() {
    super.initState();
    _checkIfTaken();
  }

  Future<void> _checkIfTaken() async {
    try {
      final hasTaken = await widget.quizService.hasTakenQuiz(
        widget.userId,
        widget.quiz.id,
      );
      if (hasTaken) {
        final results = await widget.quizService.getStudentQuizResults(
          widget.userId,
        );
        final result = results.firstWhere((r) => r.quizId == widget.quiz.id);
        if (!mounted) return;
        setState(() {
          _hasTaken = true;
          _result = result;
        });
      } else {
        if (!mounted) return;
        setState(() => _hasTaken = false);
      }
    } catch (e) {
      print('Error checking quiz status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF428DEB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Color(0xFF428DEB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.quiz.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // ✅ NEW: Status Badge
                        if (_hasTaken == true && _result != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _result!.isPassed
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _result!.isPassed ? 'Passed ✅' : 'Failed ❌',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _result!.isPassed
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${widget.quiz.questions.length} questions • ${widget.quiz.totalPoints} points',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.quiz.timeLimit > 0)
                      Text(
                        '⏱ ${widget.quiz.timeLimit} minutes',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.quiz.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.quiz.description,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (_hasTaken == true && _result != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Score: ${_result!.score}/${_result!.totalPoints} (${_result!.percentage.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _result!.isPassed
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onTakeQuiz,
                  icon: Icon(
                    _hasTaken == true
                        ? Icons.visibility
                        : Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: Text(_hasTaken == true ? 'View Results' : 'Take Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF428DEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
