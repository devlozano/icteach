import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/quiz_model.dart';
import '../../services/quiz_service.dart';
import '../../services/notification_service.dart';

class CreateQuizPage extends StatefulWidget {
  final String classId;
  final String className;
  final QuizModel? quizToEdit;

  const CreateQuizPage({
    super.key,
    required this.classId,
    this.className = '',
    this.quizToEdit,
  });

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  final _formKey = GlobalKey<FormState>();
  final QuizService _quizService = QuizService();
  final NotificationService _notificationService = NotificationService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeLimitController = TextEditingController();
  final _passingScoreController = TextEditingController(); // ✅ ADDED

  bool _isLoading = false;
  bool _isPublished = false;
  bool _isEditing = false;
  List<Question> _questions = [];
  int _totalPoints = 0;
  String? _quizId;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.quizToEdit != null;

    if (_isEditing) {
      final quiz = widget.quizToEdit!;
      _titleController.text = quiz.title;
      _descriptionController.text = quiz.description;
      _timeLimitController.text = quiz.timeLimit > 0
          ? quiz.timeLimit.toString()
          : '';
      _passingScoreController.text = quiz.passingScore > 0
          ? quiz.passingScore.toString()
          : ''; // ✅ ADDED
      _questions = List.from(quiz.questions);
      _isPublished = quiz.isPublished;
      _quizId = quiz.id;
      _calculateTotalPoints();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeLimitController.dispose();
    _passingScoreController.dispose(); // ✅ ADDED
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        Question(
          id: const Uuid().v4(),
          text: '',
          options: ['', '', '', ''],
          correctAnswer: 0,
          explanation: '',
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
    _calculateTotalPoints();
  }

  void _updateQuestion(int index, Question question) {
    setState(() {
      _questions[index] = question;
    });
    _calculateTotalPoints();
  }

  void _calculateTotalPoints() {
    setState(() {
      _totalPoints = _questions.length;
    });
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate questions
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.text.trim().isEmpty) {
        _showMessage('Please fill in question ${i + 1}');
        return;
      }
      for (int j = 0; j < q.options.length; j++) {
        if (q.options[j].trim().isEmpty) {
          _showMessage('Please fill in all options for question ${i + 1}');
          return;
        }
      }
    }

    // ✅ Validate passing score
    final passingScore = int.tryParse(_passingScoreController.text) ?? 0;
    if (passingScore < 0) {
      _showMessage('Passing score cannot be negative');
      return;
    }
    if (passingScore > _totalPoints) {
      _showMessage('Passing score cannot exceed total points ($_totalPoints)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quiz = QuizModel(
        id: _quizId ?? '',
        classId: widget.classId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        questions: _questions,
        timeLimit: int.tryParse(_timeLimitController.text) ?? 0,
        totalPoints: _totalPoints,
        passingScore: passingScore, // ✅ ADDED
        isPublished: _isPublished,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await _quizService.updateQuiz(widget.classId, _quizId!, quiz);
        if (_isPublished) {
          await _notificationService.notifyNewQuiz(
            widget.classId,
            _titleController.text.trim(),
          );
        }
      } else {
        await _quizService.createQuiz(quiz);
        if (_isPublished) {
          await _notificationService.notifyNewQuiz(
            widget.classId,
            _titleController.text.trim(),
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPublished
                ? '✅ Quiz ${_isEditing ? 'updated' : 'published'} and notifications sent!'
                : '✅ Quiz ${_isEditing ? 'updated' : 'saved'} as draft!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Error ${_isEditing ? 'updating' : 'creating'} quiz: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Quiz' : 'Create Quiz'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Switch(
            value: _isPublished,
            onChanged: (value) {
              setState(() => _isPublished = value);
            },
            activeThumbColor: Colors.green,
          ),
          const SizedBox(width: 8),
          const Text('Publish', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Name Display
              if (widget.className.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Publish a quiz with questions and unlock it in Content Lock Settings. Enrolled students can then take it. Quizzes have one scored attempt and no practice mode. No lesson link is required.',
                        ),
                      ),
                      Icon(Icons.class_, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Class: ${widget.className}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Quiz Title',
                  hintText: 'e.g., CSS Module 1 Quiz',
                  prefixIcon: Icon(Icons.quiz),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Quiz title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the quiz',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time Limit
              TextFormField(
                controller: _timeLimitController,
                decoration: const InputDecoration(
                  labelText: 'Time Limit (minutes)',
                  hintText: '0 for no time limit',
                  prefixIcon: Icon(Icons.timer),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Time limit is required';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✅ NEW: Passing Score
              TextFormField(
                controller: _passingScoreController,
                decoration: const InputDecoration(
                  labelText: 'Passing Score',
                  hintText: 'Minimum score to pass (0 for no requirement)',
                  prefixIcon: Icon(Icons.score),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Passing score is required';
                  }
                  final parsed = int.tryParse(value);
                  if (parsed == null) {
                    return 'Please enter a valid number';
                  }
                  if (parsed < 0) {
                    return 'Passing score cannot be negative';
                  }
                  if (parsed > _totalPoints && _totalPoints > 0) {
                    return 'Cannot exceed total points ($_totalPoints)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Questions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Questions (${_questions.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2B4A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Questions List
              if (_questions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.question_mark,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Add Question" to start building your quiz',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  return _QuestionCard(
                    index: index,
                    question: question,
                    onUpdate: (updated) => _updateQuestion(index, updated),
                    onRemove: () => _removeQuestion(index),
                  );
                }),

              const SizedBox(height: 24),

              // Total Points and Passing Score Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.score, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Total Points: $_totalPoints',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isPublished
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isPublished ? 'Published' : 'Draft',
                            style: TextStyle(
                              color: _isPublished
                                  ? Colors.green.shade800
                                  : Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ✅ Show passing score if set
                    if (_passingScoreController.text.isNotEmpty &&
                        int.tryParse(_passingScoreController.text) != null &&
                        int.parse(_passingScoreController.text) > 0) ...[
                      const SizedBox(height: 8),
                      Divider(color: Colors.blue.shade200),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Passing Score: ${_passingScoreController.text} / $_totalPoints',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${int.tryParse(_passingScoreController.text) != null && _totalPoints > 0 ? ((int.parse(_passingScoreController.text) / _totalPoints) * 100).toStringAsFixed(0) : 0}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notification Info
              if (_isPublished) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Students will be notified about this quiz when you save it.',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2B4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? (_isPublished
                                    ? 'Update & Publish'
                                    : 'Update Draft')
                              : (_isPublished
                                    ? 'Publish Quiz'
                                    : 'Save as Draft'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Question Card Widget
class _QuestionCard extends StatefulWidget {
  final int index;
  final Question question;
  final Function(Question) onUpdate;
  final VoidCallback onRemove;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  final _textController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final _explanationController = TextEditingController();
  int _selectedAnswer = 0;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.question.text;
    _optionControllers.addAll(
      widget.question.options.map((o) => TextEditingController(text: o)),
    );
    _explanationController.text = widget.question.explanation;
    _selectedAnswer = widget.question.correctAnswer;
  }

  @override
  void dispose() {
    _textController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    _explanationController.dispose();
    super.dispose();
  }

  void _updateQuestion() {
    final updated = widget.question.copyWith(
      text: _textController.text,
      options: _optionControllers.map((c) => c.text).toList(),
      correctAnswer: _selectedAnswer,
      explanation: _explanationController.text,
    );
    widget.onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  color: const Color(0xFF0B2B4A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${widget.index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2B4A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Enter question text',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _updateQuestion(),
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._optionControllers.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final controller = entry.value;
            return _OptionTile(
              index: optionIndex,
              controller: controller,
              isSelected: _selectedAnswer == optionIndex,
              onTap: () {
                setState(() {
                  _selectedAnswer = optionIndex;
                });
                _updateQuestion();
              },
              onChanged: (_) => _updateQuestion(),
            );
          }),
          const SizedBox(height: 8),
          TextFormField(
            controller: _explanationController,
            decoration: const InputDecoration(
              hintText: 'Explanation (optional)',
              prefixIcon: Icon(Icons.info_outline, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            onChanged: (_) => _updateQuestion(),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(String) onChanged;

  const _OptionTile({
    required this.index,
    required this.controller,
    required this.isSelected,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.green : Colors.grey.shade300,
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Option',
                  border: InputBorder.none,
                ),
                onChanged: onChanged,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}
