import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/assignment_model.dart';
import '../../services/assignment_service.dart';
import '../../services/learning_path_service.dart';
import '../../services/cloudinary_service.dart';

class SubmitAssignmentPage extends StatefulWidget {
  final String classId;
  final AssignmentModel assignment;

  const SubmitAssignmentPage({
    super.key,
    required this.classId,
    required this.assignment,
  });

  @override
  State<SubmitAssignmentPage> createState() => _SubmitAssignmentPageState();
}

class _SubmitAssignmentPageState extends State<SubmitAssignmentPage> {
  final AssignmentService _assignmentService = AssignmentService();
  final TextEditingController _contentController = TextEditingController();

  bool _isSubmitting = false;
  PlatformFile? _selectedFile;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectSubmissionFile() async {
    try {
      final file = await CloudinaryService.selectFile();
      if (file == null || !mounted) return;
      setState(() => _selectedFile = file);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _submitAssignment() async {
    // Check if content is provided
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write your answer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check minimum character requirement
    if (content.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide a more detailed answer (at least 10 characters)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      CloudinaryUploadResult? uploadedFile;
      if (_selectedFile != null) {
        uploadedFile = await CloudinaryService.uploadFile(
          file: _selectedFile!,
          folder: CloudinaryService.submissionsFolder,
        );
      }

      final submission = AssignmentSubmission(
        id: '',
        classId: widget.classId,
        assignmentId: widget.assignment.id,
        studentId: user.uid,
        studentName: user.displayName ?? 'Student',
        content: content,
        attachmentUrl: uploadedFile?.url,
        attachmentName: uploadedFile?.originalFilename,
        cloudinaryPublicId: uploadedFile?.publicId,
        score: 0,
        submittedAt: DateTime.now(),
        isGraded: false,
      );

      await LearningPathService.requireActive(widget.classId);
      await _assignmentService.submitAssignment(submission);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Assignment submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error submitting assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _getCharacterCountText() {
    final length = _contentController.text.length;
    return length == 0
        ? '0 characters (minimum 10)'
        : '$length characters (minimum 10)';
  }

  Color _getCharacterCountColor() {
    final length = _contentController.text.length;
    if (length == 0) return Colors.grey[400]!;
    if (length < 10) return Colors.orange;
    return Colors.green[700]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text('Submit Assignment'),
        backgroundColor: const Color(0xFF428DEB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment Info Card
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
                  Text(
                    widget.assignment.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${widget.assignment.dueDate.day}/${widget.assignment.dueDate.month}/${widget.assignment.dueDate.year}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.assignment.description,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Max Score: ${widget.assignment.maxScore}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF428DEB),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instructions Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Write your answer in the box below. Minimum 10 characters required.',
                      style: TextStyle(color: Colors.blue[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content Label
            const Text(
              'Your Answer:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Auto-Expanding TextField with Max Height
            Container(
              constraints: BoxConstraints(
                minHeight: 200,
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: TextFormField(
                controller: _contentController,
                maxLines: null,
                minLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: 'Your Answer',
                  hintText: 'Write your answer here...',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.grey[50],
                  counterText: '',
                  contentPadding: const EdgeInsets.all(16),
                  helperText: _getCharacterCountText(),
                  helperStyle: TextStyle(
                    color: _getCharacterCountColor(),
                    fontSize: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please write your answer';
                  }
                  if (value.length < 10) {
                    return 'Your answer should be at least 10 characters';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _selectSubmissionFile,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _selectedFile?.name ?? 'Attach supporting file (optional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            if (_selectedFile != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _selectedFile = null),
                  icon: const Icon(Icons.close, size: 17),
                  label: const Text('Remove selected file'),
                ),
              ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAssignment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Submit Assignment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
