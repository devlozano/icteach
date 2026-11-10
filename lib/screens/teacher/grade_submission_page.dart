import 'package:flutter/material.dart';
import '../../utils/score_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/assignment_model.dart';
import '../../services/assignment_service.dart';
import '../../services/notification_service.dart';

class GradeSubmissionPage extends StatefulWidget {
  final String classId;
  final String assignmentId;
  final String assignmentTitle;
  final AssignmentSubmission submission;

  const GradeSubmissionPage({
    super.key,
    required this.classId,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.submission,
  });

  @override
  State<GradeSubmissionPage> createState() => _GradeSubmissionPageState();
}

class _GradeSubmissionPageState extends State<GradeSubmissionPage> {
  final AssignmentService _assignmentService = AssignmentService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  int? _selectedScore;

  @override
  void initState() {
    super.initState();
    if (widget.submission.isGraded) {
      _scoreController.text = widget.submission.score.toString();
      _feedbackController.text = widget.submission.feedback ?? '';
      _selectedScore = widget.submission.score;
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitGrade() async {
    final score = int.tryParse(_scoreController.text.trim());
    if (score == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid score'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate score range
    if (score < 0 || score > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Score must be between 0 and 100'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get the submission ID (it's stored as '${assignmentId}_${studentId}')
      final submissionId =
          '${widget.assignmentId}_${widget.submission.studentId}';

      await _assignmentService.gradeSubmission(
        submissionId,
        score,
        _feedbackController.text.trim(),
      );

      // ✅ SEND NOTIFICATION TO STUDENT - CORRECT WAY
      await _notificationService.notifyGrade(
        widget.submission.studentId, // studentId
        widget.assignmentTitle, // assignmentTitle
        score, // score
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Submission graded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error grading submission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text('Grade: ${widget.assignmentTitle}'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info
            Container(
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
                  const Text(
                    'Student Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          widget.submission.studentName.isNotEmpty
                              ? widget.submission.studentName[0].toUpperCase()
                              : 'S',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.submission.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Submitted: ${_formatDate(widget.submission.submittedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.submission.isGraded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Graded: ${widget.submission.score}/100',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Submission Content
            Container(
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
                  const Text(
                    'Student Submission',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      widget.submission.content.isNotEmpty
                          ? widget.submission.content
                          : 'No content provided',
                      style: const TextStyle(height: 1.6, fontSize: 14),
                    ),
                  ),
                  if (widget.submission.attachmentUrl != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        try {
                          final uri = Uri.parse(
                            widget.submission.attachmentUrl!,
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e) {
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error opening file: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'View Attachment',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.open_in_new,
                              color: Colors.blue,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Grading Section
            Container(
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
                  const Text(
                    'Grading',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Score Input
                  TextFormField(
                    controller: _scoreController,
                    inputFormatters: [
                      ScoreInputFormatter(decimal: false, maximum: 100),
                    ],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Score (out of 100)',
                      hintText: 'Enter score (0-100)',
                      prefixIcon: const Icon(Icons.score),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      suffixText: '/ 100',
                      suffixStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                      helperText: 'Enter a score between 0 and 100',
                      helperStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                    onChanged: (value) {
                      _selectedScore = int.tryParse(value);
                      setState(() {});
                    },
                  ),
                  // Score visual indicator
                  if (_selectedScore != null) ...[
                    const SizedBox(height: 12),
                    _buildScoreIndicator(_selectedScore!),
                  ],
                  const SizedBox(height: 16),
                  // Feedback Input
                  TextFormField(
                    controller: _feedbackController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Feedback',
                      hintText: 'Provide detailed feedback to the student...',
                      prefixIcon: Icon(Icons.feedback_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quick feedback buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickFeedbackChip(
                        label: '🌟 Excellent!',
                        onTap: () {
                          setState(() {
                            _feedbackController.text =
                                'Excellent work! You demonstrated a thorough understanding of the topic. Keep up the great effort! 🌟🎉';
                          });
                        },
                      ),
                      _QuickFeedbackChip(
                        label: '💪 Good job!',
                        onTap: () {
                          setState(() {
                            _feedbackController.text =
                                'Good job! You showed a solid understanding of the concepts. Keep learning and practicing to improve further! 💪✨';
                          });
                        },
                      ),
                      _QuickFeedbackChip(
                        label: '📚 Needs review',
                        onTap: () {
                          setState(() {
                            _feedbackController.text =
                                'You showed some understanding, but there are areas that need improvement. Please review the material and try again. I\'m here to help! 📚🤝';
                          });
                        },
                      ),
                      _QuickFeedbackChip(
                        label: '⭐ Great effort!',
                        onTap: () {
                          setState(() {
                            _feedbackController.text =
                                'Great effort! I can see you put time and thought into this. Continue practicing and you\'ll improve even more! ⭐💫';
                          });
                        },
                      ),
                      _QuickFeedbackChip(
                        label: '🎯 Well done!',
                        onTap: () {
                          setState(() {
                            _feedbackController.text =
                                'Well done! Your work shows good understanding and attention to detail. Keep pushing forward! 🎯👏';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitGrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF428DEB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.submission.isGraded
                                  ? 'Update Grade'
                                  : 'Submit Grade',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (widget.submission.isGraded) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'This submission was previously graded. Updating will overwrite the existing grade.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(int score) {
    Color color;
    String label;
    IconData icon;

    if (score >= 90) {
      color = Colors.green;
      label = 'Excellent';
      icon = Icons.emoji_events;
    } else if (score >= 75) {
      color = Colors.blue;
      label = 'Good';
      icon = Icons.thumb_up;
    } else if (score >= 60) {
      color = Colors.orange;
      label = 'Satisfactory';
      icon = Icons.check_circle;
    } else {
      color = Colors.red;
      label = 'Needs Improvement';
      icon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Score: $score/100',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Quick Feedback Chip
class _QuickFeedbackChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickFeedbackChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      backgroundColor: Colors.grey.shade100,
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
    );
  }
}
