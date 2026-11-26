import 'package:cloud_firestore/cloud_firestore.dart';

class QuizModel {
  final String id;
  final String classId;
  final String title;
  final String description;
  final List<Question> questions;
  final int timeLimit; // in minutes
  final int totalPoints;
  final int passingScore; // ✅ ADDED: Passing score requirement
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuizModel({
    required this.id,
    required this.classId,
    required this.title,
    required this.description,
    required this.questions,
    required this.timeLimit,
    required this.totalPoints,
    this.passingScore = 0, // ✅ ADDED with default
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuizModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return QuizModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      title: data['title'] ?? 'Untitled Quiz',
      description: data['description'] ?? '',
      questions:
          (data['questions'] as List?)
              ?.map((q) => Question.fromMap(q))
              .toList() ??
          [],
      timeLimit: data['timeLimit'] ?? 0,
      totalPoints: data['totalPoints'] ?? 0,
      passingScore: data['passingScore'] ?? 0, // ✅ ADDED
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toMap()).toList(),
      'timeLimit': timeLimit,
      'totalPoints': totalPoints,
      'passingScore': passingScore, // ✅ ADDED
      'isPublished': isPublished,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  QuizModel copyWith({
    String? id,
    String? classId,
    String? title,
    String? description,
    List<Question>? questions,
    int? timeLimit,
    int? totalPoints,
    int? passingScore, // ✅ ADDED
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      title: title ?? this.title,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      timeLimit: timeLimit ?? this.timeLimit,
      totalPoints: totalPoints ?? this.totalPoints,
      passingScore: passingScore ?? this.passingScore, // ✅ ADDED
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Question Model (keep as is, or update if needed)
enum QuestionType { multipleChoice, trueFalse, fillInTheBlank, enumeration }

extension QuestionTypeLabel on QuestionType {
  String get label => switch (this) {
    QuestionType.multipleChoice => 'Multiple choice',
    QuestionType.trueFalse => 'True or false',
    QuestionType.fillInTheBlank => 'Fill in the blank',
    QuestionType.enumeration => 'Enumeration',
  };
}

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final QuestionType type;
  final List<String> acceptedAnswers;
  final int points; // ✅ Optional: points per question

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctAnswer,
    this.explanation = '',
    this.type = QuestionType.multipleChoice,
    this.acceptedAnswers = const [],
    this.points = 1, // ✅ Default points per question
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? QuestionType.multipleChoice.name;
    return Question(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      options: List<String>.from(map['options'] ?? ['', '', '', '']),
      correctAnswer: map['correctAnswer'] ?? 0,
      explanation: map['explanation'] ?? '',
      type:
          QuestionType.values
              .where((type) => type.name == typeName)
              .firstOrNull ??
          QuestionType.multipleChoice,
      acceptedAnswers: List<String>.from(map['acceptedAnswers'] ?? const []),
      points: map['points'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'type': type.name,
      'acceptedAnswers': acceptedAnswers,
      'points': points,
    };
  }

  Question copyWith({
    String? id,
    String? text,
    List<String>? options,
    int? correctAnswer,
    String? explanation,
    QuestionType? type,
    List<String>? acceptedAnswers,
    int? points,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      type: type ?? this.type,
      acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
      points: points ?? this.points,
    );
  }

  bool matchesText(String answer) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final normalized = normalize(answer);
    return normalized.isNotEmpty &&
        acceptedAnswers.any((value) => normalize(value) == normalized);
  }
}

// Quiz Result Model
class QuizResult {
  final double passingPercentage;
  final String quizId;
  final String classId; // ✅ ADDED
  final String studentId;
  final String studentName;
  final int score;
  final int totalPoints;
  final List<UserAnswer> userAnswers;
  final DateTime completedAt;
  final int timeSpent; // in seconds
  final bool retryAllowed;
  final String teacherFeedback;
  final int attemptNumber;

  QuizResult({
    this.passingPercentage = 60,
    required this.quizId,
    required this.classId, // ✅ ADDED
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.totalPoints,
    required this.userAnswers,
    required this.completedAt,
    required this.timeSpent,
    this.retryAllowed = false,
    this.teacherFeedback = '',
    this.attemptNumber = 1,
  });

  factory QuizResult.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return QuizResult(
      passingPercentage: (data['passingPercentage'] as num?)?.toDouble() ?? 60,
      quizId: data['quizId'] ?? '',
      classId: data['classId'] ?? '', // ✅ ADDED
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      score: data['score'] ?? 0,
      totalPoints: data['totalPoints'] ?? 0,
      userAnswers:
          (data['userAnswers'] as List?)
              ?.map((a) => UserAnswer.fromMap(a))
              .toList() ??
          [],
      completedAt:
          (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeSpent: data['timeSpent'] ?? 0,
      retryAllowed: data['retryAllowed'] == true,
      teacherFeedback: data['teacherFeedback']?.toString() ?? '',
      attemptNumber: (data['attemptNumber'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'quizId': quizId,
      if (passingPercentage != 60) 'passingPercentage': passingPercentage,
      'classId': classId, // ✅ ADDED
      'studentId': studentId,
      'studentName': studentName,
      'score': score,
      'totalPoints': totalPoints,
      // A student result is readable from the student's workspace. Do not
      // persist the answer key, explanations, or per-item correctness there:
      // the total score is the feedback released to students.
      'userAnswers': userAnswers
          .map(
            (a) => {
              'questionId': a.questionId,
              'selectedAnswer': a.selectedAnswer,
              'textAnswer': a.textAnswer,
            },
          )
          .toList(),
      'completedAt': FieldValue.serverTimestamp(),
      'timeSpent': timeSpent,
      'retryAllowed': retryAllowed,
      'teacherFeedback': teacherFeedback,
      'attemptNumber': attemptNumber,
    };
  }

  double get percentage => totalPoints > 0 ? (score / totalPoints) * 100 : 0;
  bool get isPassed => percentage >= passingPercentage;
}

class UserAnswer {
  final String questionId;
  final int selectedAnswer; // index of selected option
  final bool isCorrect;
  final String correctAnswerText;
  final String explanation;
  final String textAnswer;

  UserAnswer({
    required this.questionId,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.correctAnswerText,
    required this.explanation,
    this.textAnswer = '',
  });

  factory UserAnswer.fromMap(Map<String, dynamic> map) {
    return UserAnswer(
      questionId: map['questionId'] ?? '',
      selectedAnswer: map['selectedAnswer'] ?? 0,
      isCorrect: map['isCorrect'] ?? false,
      correctAnswerText: map['correctAnswerText'] ?? '',
      explanation: map['explanation'] ?? '',
      textAnswer: map['textAnswer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'selectedAnswer': selectedAnswer,
      'isCorrect': isCorrect,
      'correctAnswerText': correctAnswerText,
      'explanation': explanation,
      'textAnswer': textAnswer,
    };
  }
}
