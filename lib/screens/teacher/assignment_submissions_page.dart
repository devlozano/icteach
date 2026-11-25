import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/assignment_model.dart';
import '../../services/assignment_service.dart';
import 'grade_submission_page.dart';

class AssignmentSubmissionsPage extends StatefulWidget {
  final String classId;
  final String assignmentId;
  final String assignmentTitle;

  const AssignmentSubmissionsPage({
    super.key,
    required this.classId,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<AssignmentSubmissionsPage> createState() =>
      _AssignmentSubmissionsPageState();
}

class _AssignmentSubmissionsPageState extends State<AssignmentSubmissionsPage> {
  final AssignmentService _assignmentService = AssignmentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text('Submissions: ${widget.assignmentTitle}'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<AssignmentSubmission>>(
        future: _assignmentService.getSubmissionsForAssignment(
          widget.classId,
          widget.assignmentId,
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

          final submissions = snapshot.data ?? [];

          if (submissions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No submissions yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Students haven\'t submitted this assignment yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final totalSubmissions = submissions.length;
          final gradedCount = submissions.where((s) => s.isGraded).length;
          final averageScore = gradedCount > 0
              ? submissions
                        .where((s) => s.isGraded)
                        .fold<double>(0, (sum, s) => sum + s.score) /
                    gradedCount
              : 0;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      label: 'Total',
                      value: '$totalSubmissions',
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                    _StatChip(
                      label: 'Graded',
                      value: '$gradedCount',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    _StatChip(
                      label: 'Pending',
                      value: '${totalSubmissions - gradedCount}',
                      icon: Icons.hourglass_empty,
                      color: Colors.orange,
                    ),
                    if (gradedCount > 0)
                      _StatChip(
                        label: 'Avg Score',
                        value: '${averageScore.toStringAsFixed(0)}%',
                        icon: Icons.trending_up,
                        color: Colors.purple,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final submission = submissions[index];
                    return _SubmissionCard(
                      submission: submission,
                      onGrade: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GradeSubmissionPage(
                              classId: widget.classId,
                              assignmentId: widget.assignmentId,
                              assignmentTitle: widget.assignmentTitle,
                              submission: submission,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override // ✅ FIXED
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final AssignmentSubmission submission;
  final VoidCallback onGrade;

  const _SubmissionCard({required this.submission, required this.onGrade});

  Future<void> _openAttachment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening attachment: $e');
    }
  }

  @override // ✅ FIXED
  Widget build(BuildContext context) {
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
        border: submission.isGraded
            ? Border.all(color: Colors.green.shade300, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: submission.isGraded
                    ? Colors.green.shade100
                    : Colors.blue.shade100,
                radius: 18,
                child: Text(
                  submission.studentName.isNotEmpty
                      ? submission.studentName[0].toUpperCase()
                      : 'S',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: submission.isGraded
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Submitted: ${submission.submittedAt.day}/${submission.submittedAt.month}/${submission.submittedAt.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (submission.isGraded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${submission.score} pts',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showSubmissionContent(context);
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0B2B4A),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onGrade,
                  icon: Icon(
                    submission.isGraded ? Icons.edit : Icons.grade,
                    size: 16,
                  ),
                  label: Text(submission.isGraded ? 'Update' : 'Grade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: submission.isGraded
                        ? Colors.orange
                        : const Color(0xFF428DEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSubmissionContent(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submission Content'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (submission.content.isNotEmpty) ...[
                const Text(
                  'Content:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(submission.content, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 12),
              ],
              if (submission.attachmentUrl != null) ...[
                const Text(
                  'Attachment:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _openAttachment(submission.attachmentUrl!),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('View Attachment'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
