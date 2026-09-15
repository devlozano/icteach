import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/assignment_model.dart';
import '../../services/assignment_service.dart';
import 'submit_assignment_page.dart';

class StudentAssignmentsPage extends StatefulWidget {
  final String classId;
  final String className;

  const StudentAssignmentsPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<StudentAssignmentsPage> createState() => _StudentAssignmentsPageState();
}

class _StudentAssignmentsPageState extends State<StudentAssignmentsPage> {
  final AssignmentService _assignmentService = AssignmentService();
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text('Assignments - ${widget.className}'),
        backgroundColor: const Color(0xFF428DEB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<AssignmentModel>>(
        stream: _assignmentService.getPublishedAssignmentsForClass(
          widget.classId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final assignments = snapshot.data ?? [];

          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No assignments available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for assignments',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              return _StudentAssignmentCard(
                assignment: assignment,
                userId: user?.uid ?? '',
                assignmentService: _assignmentService,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubmitAssignmentPage(
                        classId: widget.classId,
                        assignment: assignment,
                      ),
                    ),
                  ).then((_) {
                    setState(() {});
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StudentAssignmentCard extends StatefulWidget {
  final AssignmentModel assignment;
  final String userId;
  final AssignmentService assignmentService;
  final VoidCallback onTap;

  const _StudentAssignmentCard({
    required this.assignment,
    required this.userId,
    required this.assignmentService,
    required this.onTap,
  });

  @override
  State<_StudentAssignmentCard> createState() => _StudentAssignmentCardState();
}

class _StudentAssignmentCardState extends State<_StudentAssignmentCard> {
  bool _hasSubmitted = false;
  bool _isChecking = true;
  AssignmentSubmission? _submission;

  @override
  void initState() {
    super.initState();
    _checkSubmissionStatus();
  }

  Future<void> _checkSubmissionStatus() async {
    if (widget.userId.isEmpty) {
      setState(() {
        _isChecking = false;
        _hasSubmitted = false;
      });
      return;
    }

    try {
      final submission = await widget.assignmentService.getStudentSubmission(
        widget.assignment.id,
      );

      setState(() {
        _submission = submission;
        _hasSubmitted = submission != null;
        _isChecking = false;
      });
    } catch (e) {
      print('Error checking submission: $e');
      setState(() {
        _isChecking = false;
        _hasSubmitted = false;
      });
    }
  }

  Future<void> _openAttachment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open attachment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error opening attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening attachment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = widget.assignment.dueDate
        .difference(DateTime.now())
        .inDays;
    final isOverdue = daysLeft < 0;
    final isDueSoon = daysLeft >= 0 && daysLeft <= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
        border: _hasSubmitted
            ? Border.all(color: Colors.green.shade300, width: 2)
            : isOverdue
            ? Border.all(color: Colors.red.shade300, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _hasSubmitted
                      ? Colors.green.shade100
                      : const Color(0xFF428DEB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _hasSubmitted ? Icons.check_circle : Icons.assignment,
                  color: _hasSubmitted ? Colors.green : const Color(0xFF428DEB),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.assignment.title,
                            style: TextStyle(
                              fontWeight: _hasSubmitted
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: _hasSubmitted
                                  ? Colors.green.shade800
                                  : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // ✅ Status Badge - Smaller
                        if (_hasSubmitted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 10,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Submitted',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isOverdue) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Overdue',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ] else if (isDueSoon) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Due Soon',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // ✅ Due date row - More compact
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 11,
                          color: isOverdue ? Colors.red : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Due: ${widget.assignment.dueDate.day}/${widget.assignment.dueDate.month}/${widget.assignment.dueDate.year}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (!isOverdue && !_hasSubmitted) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isDueSoon
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$daysLeft days',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: isDueSoon
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ✅ Description - Smaller text
          Text(
            widget.assignment.description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.assignment.attachmentUrl != null &&
              widget.assignment.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    _openAttachment(widget.assignment.attachmentUrl!),
                icon: const Icon(Icons.description_outlined, size: 17),
                label: Text(
                  widget.assignment.attachmentName ?? 'Open assignment brief',
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // ✅ Row with smaller text and buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Max Score: ${widget.assignment.maxScore}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_hasSubmitted &&
                  _submission != null &&
                  _submission!.isGraded) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Score: ${_submission!.score}/${widget.assignment.maxScore}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (_isChecking)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_hasSubmitted)
                // ✅ Smaller "View" button
                SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: () {
                      _showSubmissionDetails(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF428DEB),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('View'),
                  ),
                )
              else if (isOverdue)
                const Chip(
                  label: Text('Closed'),
                  avatar: Icon(Icons.lock_clock, size: 16),
                  visualDensity: VisualDensity.compact,
                )
              else
                // ✅ Smaller "Submit" button
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: widget.onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF428DEB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Submit'),
                  ),
                ),
            ],
          ),
          if (_hasSubmitted &&
              _submission != null &&
              _submission!.feedback != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.feedback_outlined,
                    size: 14,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _submission!.feedback!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSubmissionDetails(BuildContext context) {
    if (_submission == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Submission Details',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                    maxHeight: 650,
                  ),
                  child: _SubmissionDetailsContent(
                    submission: _submission!,
                    assignment: widget.assignment,
                    onOpenAttachment: _openAttachment,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }
}

// ✅ Fixed: Submission Details Content
class _SubmissionDetailsContent extends StatefulWidget {
  final AssignmentSubmission submission;
  final AssignmentModel assignment;
  final void Function(String) onOpenAttachment;

  const _SubmissionDetailsContent({
    required this.submission,
    required this.assignment,
    required this.onOpenAttachment,
  });

  @override
  State<_SubmissionDetailsContent> createState() =>
      _SubmissionDetailsContentState();
}

class _SubmissionDetailsContentState extends State<_SubmissionDetailsContent> {
  bool _showFullAnswer = false;

  @override
  Widget build(BuildContext context) {
    final isGraded = widget.submission.isGraded;
    final percentage = isGraded
        ? (widget.submission.score / widget.assignment.maxScore * 100)
        : 0;
    final isPassed = percentage >= 70;
    final scoreColor = isPassed ? Colors.green : Colors.orange;

    final formattedContent = widget.submission.content
        .replaceAll('1. ', '\n1. ')
        .replaceAll('2. ', '\n2. ')
        .replaceAll('3. ', '\n3. ')
        .replaceAll('4. ', '\n4. ')
        .replaceAll('5. ', '\n5. ')
        .replaceAll('6. ', '\n6. ')
        .replaceAll('7. ', '\n7. ')
        .replaceAll('8. ', '\n8. ')
        .replaceAll('9. ', '\n9. ')
        .replaceAll('10. ', '\n10. ')
        .trim();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isGraded
                      ? isPassed
                            ? [Colors.green.shade700, Colors.green.shade500]
                            : [Colors.orange.shade700, Colors.orange.shade500]
                      : [const Color(0xFF428DEB), const Color(0xFF2F80ED)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGraded
                          ? isPassed
                                ? Icons.emoji_events
                                : Icons.sentiment_dissatisfied
                          : Icons.pending_actions,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isGraded
                        ? isPassed
                              ? '🎉 Excellent Work!'
                              : 'Keep Improving!'
                        : 'Pending Review',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGraded
                        ? isPassed
                              ? 'You passed this assignment!'
                              : 'Review the feedback to improve'
                        : 'Your submission is being reviewed by the teacher',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Assignment Title
                  Row(
                    children: [
                      const Icon(
                        Icons.assignment,
                        size: 16,
                        color: Color(0xFF428DEB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.assignment.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Score Card
                  if (isGraded) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scoreColor.withOpacity(0.1),
                            scoreColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scoreColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scoreColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                widget.submission.score.toString(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Score: ${widget.submission.score}/${widget.assignment.maxScore}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: scoreColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isPassed
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isPassed ? '✅ Passed' : '⚠️ Failed',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isPassed
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Feedback
                    if (widget.submission.feedback != null) ...[
                      const Text(
                        '📝 Feedback',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.format_quote,
                              size: 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.submission.feedback!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_top,
                            color: Colors.amber,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '⏳ Awaiting Review',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                                Text(
                                  'The teacher will review your submission soon.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Review Your Answer Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showFullAnswer = !_showFullAnswer;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                  color: Color(0xFF428DEB),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Review Your Answer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _showFullAnswer
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showFullAnswer) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedContent,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    height: 1.6,
                                  ),
                                ),
                                if (widget.submission.attachmentUrl !=
                                    null) ...[
                                  const SizedBox(height: 10),
                                  TextButton.icon(
                                    onPressed: () => widget.onOpenAttachment(
                                      widget.submission.attachmentUrl!,
                                    ),
                                    icon: const Icon(
                                      Icons.attach_file,
                                      size: 16,
                                    ),
                                    label: const Text('View Attachment'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Submission Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: 'Submitted',
                          value:
                              '${widget.submission.submittedAt.day}/${widget.submission.submittedAt.month}/${widget.submission.submittedAt.year} at ${widget.submission.submittedAt.hour}:${widget.submission.submittedAt.minute.toString().padLeft(2, '0')}',
                        ),
                        const Divider(height: 10),
                        _InfoRow(
                          icon: Icons.schedule,
                          label: 'Due Date',
                          value:
                              '${widget.assignment.dueDate.day}/${widget.assignment.dueDate.month}/${widget.assignment.dueDate.year}',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Helper Widget: Info Row
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
