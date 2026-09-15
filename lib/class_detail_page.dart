import 'screens/student/classmates_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/user_roles_button.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/student/student_quizzes_page.dart';
import '../screens/student/student_assignments_page.dart';
import '../screens/student/module_view_page.dart';
import '../screens/student/forums_page.dart';
import '../screens/teacher/manage_quizzes_page.dart';
import '../screens/teacher/manage_assignments_page.dart';
import '../screens/teacher/manage_modules_page.dart';
import '../screens/teacher/manage_questionnaires_page.dart';
import '../screens/teacher/progress_tracker_page.dart';
import '../screens/student/student_questionnaires_page.dart';
import '../services/navigation_service.dart';

class ClassDetailPage extends StatefulWidget {
  final String classId;
  final String className;

  const ClassDetailPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _userRole = data?['role']?.toString() ?? 'student';
          });
        }
      } catch (e) {
        print('Error getting user role: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use NavigationService for back handling
    return WillPopScope(
      onWillPop: () => NavigationService.onWillPop(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.className),
          backgroundColor: const Color(0xFF428DEB),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationService.goBack(context),
            tooltip: 'Back',
          ),
          actions: [
            const UserRolesButton(),
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              onPressed: () => _showLeaveClassDialog(context),
              tooltip: 'Leave Class',
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .doc(widget.classId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Class not found'));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final classCode = data['classCode']?.toString() ?? 'N/A';
            if (data['status'] == 'archived')
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.archive_outlined, size: 48),
                      Text('Archived class • ${data['schoolYear'] ?? ''}'),
                      const Text(
                        'Previous records are preserved. Join your current school-year class to continue learning.',
                      ),
                      if (_userRole == 'teacher' ||
                          _userRole == 'trainer' ||
                          _userRole == 'admin')
                        TextButton(
                          onPressed: _navigateToInsights,
                          child: const Text('View archived class reports'),
                        ),
                    ],
                  ),
                ),
              );
            final teacherName =
                data['teacherName']?.toString() ?? 'Unknown Teacher';
            final description =
                data['description']?.toString() ?? 'No description';
            final sectionCode = data['sectionCode']?.toString() ?? 'N/A';
            final studentCount =
                (data['enrolledStudentIds'] as List?)?.length ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF428DEB,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.class_rounded,
                                color: Color(0xFF428DEB),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.className,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Teacher: $teacherName',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Class Code Badge
                            InkWell(
                              onTap: () =>
                                  _showQRCodeDialog(context, classCode),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.qr_code,
                                      size: 14,
                                      color: Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      classCode,
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoChip(
                                icon: Icons.people,
                                label: 'Students',
                                value: '$studentCount',
                              ),
                            ),
                            Expanded(
                              child: _buildInfoChip(
                                icon: Icons.group_work,
                                label: 'Section',
                                value: sectionCode,
                              ),
                            ),
                            Expanded(
                              child: _buildInfoChip(
                                icon: Icons.description,
                                label: 'Status',
                                value: 'Active',
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick Actions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildActionChip(
                              icon: Icons.menu_book_rounded,
                              label: 'Modules',
                              color: const Color(0xFF4F6DB8),
                              onTap: () => _navigateToModules(),
                            ),
                            _buildActionChip(
                              icon: Icons.quiz_rounded,
                              label: 'Quizzes',
                              color: const Color(0xFF9C4FA1),
                              onTap: () => _navigateToQuizzes(),
                            ),
                            _buildActionChip(
                              icon: Icons.assignment_rounded,
                              label: 'Assignments',
                              color: const Color(0xFFE76C31),
                              onTap: () => _navigateToAssignments(),
                            ),
                            _buildActionChip(
                              icon: Icons.forum_rounded,
                              label: 'Forum',
                              color: const Color(0xFF168D92),
                              onTap: () => _navigateToForum(),
                            ),
                            _buildActionChip(
                              icon: Icons.assessment_rounded,
                              label: 'Results',
                              color: const Color(0xFFE74C3C),
                              onTap: () => _navigateToResults(),
                            ),
                            if (_userRole == 'teacher' ||
                                _userRole == 'trainer')
                              _buildActionChip(
                                icon: Icons.insights_rounded,
                                label: 'Class Insights',
                                color: const Color(0xFF0B6B91),
                                onTap: () => _navigateToInsights(),
                              ),
                            _buildActionChip(
                              icon: Icons.rate_review_rounded,
                              label:
                                  _userRole == 'teacher' ||
                                      _userRole == 'trainer'
                                  ? 'Evaluations'
                                  : 'Give Feedback',
                              color: const Color(0xFF7C3AED),
                              onTap: () => _navigateToQuestionnaires(),
                            ),
                            _buildActionChip(
                              icon: Icons.people_rounded,
                              label: 'Classmates',
                              color: const Color(0xFF249A38),
                              onTap: () => _navigateToClassmates(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Leave Class Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLeaveClassDialog(context),
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: const Text('Leave Class'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Navigation Methods using NavigationService
  void _navigateToModules() {
    NavigationService.navigateTo(
      context,
      _userRole == 'teacher' || _userRole == 'trainer'
          ? ManageModulesPage(
              classId: widget.classId,
              className: widget.className,
            )
          : ModuleViewPage(
              classId: widget.classId,
              className: widget.className,
            ),
    );
  }

  void _navigateToQuizzes() {
    NavigationService.navigateTo(
      context,
      _userRole == 'teacher' || _userRole == 'trainer'
          ? ManageQuizzesPage(
              classId: widget.classId,
              className: widget.className,
            )
          : StudentQuizzesPage(
              classId: widget.classId,
              className: widget.className,
            ),
    );
  }

  void _navigateToAssignments() {
    NavigationService.navigateTo(
      context,
      _userRole == 'teacher' || _userRole == 'trainer'
          ? ManageAssignmentsPage(
              classId: widget.classId,
              className: widget.className,
            )
          : StudentAssignmentsPage(
              classId: widget.classId,
              className: widget.className,
            ),
    );
  }

  void _navigateToForum() {
    NavigationService.navigateTo(
      context,
      ForumsPage(classId: widget.classId, className: widget.className),
    );
  }

  void _navigateToResults() {
    // Each quiz supplies its real ID to the result screen; never use an empty ID.
    NavigationService.navigateTo(
      context,
      _userRole == 'teacher' || _userRole == 'trainer'
          ? ManageQuizzesPage(
              classId: widget.classId,
              className: widget.className,
            )
          : StudentQuizzesPage(
              classId: widget.classId,
              className: widget.className,
            ),
    );
  }

  void _navigateToInsights() {
    NavigationService.navigateTo(
      context,
      ProgressTrackerPage(classId: widget.classId, className: widget.className),
    );
  }

  void _navigateToQuestionnaires() {
    final isStaff = _userRole == 'teacher' || _userRole == 'trainer';
    NavigationService.navigateTo(
      context,
      isStaff
          ? ManageQuestionnairesPage(
              classId: widget.classId,
              className: widget.className,
            )
          : StudentQuestionnairesPage(
              classId: widget.classId,
              className: widget.className,
            ),
    );
  }

  void _navigateToClassmates() {
    NavigationService.navigateTo(
      context,
      ClassmatesPage(classId: widget.classId, className: widget.className),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  void _showLeaveClassDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Class'),
          content: Text('Are you sure you want to leave ${widget.className}?'),
          actions: [
            TextButton(
              onPressed: () => NavigationService.goBack(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                NavigationService.goBack(context);
                await _leaveClass();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveClass() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
            'enrolledStudentIds': FieldValue.arrayRemove([user.uid]),
          });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .doc(widget.classId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have left the class'),
          backgroundColor: Colors.green,
        ),
      );

      NavigationService.goBack(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error leaving class: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyClassCode(BuildContext context, String classCode) {
    if (classCode.isEmpty || classCode == 'N/A') return;
    Clipboard.setData(ClipboardData(text: classCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Class code "$classCode" copied!'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareQRCode(String classCode) async {
    if (classCode.isEmpty || classCode == 'N/A') return;
    // ignore: deprecated_member_use
    await Share.share(
      'Join my ICTeach class using Class Code: $classCode',
      subject: 'ICTeach Class Code',
    );
  }

  Widget _buildQRCode(BuildContext context, String classCode) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Class QR Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan to join class',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: classCode,
                version: QrVersions.auto,
                size: 200,
                gapless: false,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Class Code: $classCode',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyClassCode(context, classCode),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Code'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareQRCode(classCode),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF428DEB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context, String classCode) {
    showDialog(
      context: context,
      builder: (context) => _buildQRCode(context, classCode),
    );
  }
}
