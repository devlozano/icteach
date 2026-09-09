import 'screens/staff_management_page.dart';
import 'widgets/workspace_intro.dart';
import 'widgets/persistent_workspace.dart';
import 'screens/staff_outcomes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login.dart';
import 'admin_login.dart';
import 'widgets/staff_sidebar.dart';
import 'services/workspace_preferences.dart';
import 'join_class.dart';
import 'class_detail_page.dart';
import '../screens/teacher/manage_modules_page.dart';
import '../screens/teacher/manage_quizzes_page.dart';
import '../screens/teacher/manage_assignments_page.dart';
import 'package:icteach/screens/notification_page.dart';
import 'package:icteach/widgets/notification_badge.dart';
import 'package:icteach/screens/student/forums_page.dart';
import 'package:icteach/screens/teacher/progress_tracker_page.dart';

class TrainerHomePage extends StatefulWidget {
  const TrainerHomePage({super.key});

  @override
  State<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends State<TrainerHomePage> {
  int _selectedIndex = WorkspacePreferences.tab('trainer', 7);
  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    WorkspacePreferences.saveTab('trainer', index);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      PersistentWorkspace.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => kIsWeb ? const AdminLoginPage() : const LoginPage(),
        ),
        (route) => false,
      );
    }
  }

  String _trainerName(Map<String, dynamic>? profile, User user) {
    if (profile == null) {
      return user.displayName ?? 'Trainer';
    }

    final firstName = profile['firstName']?.toString().trim() ?? '';
    final middleName = profile['middleName']?.toString().trim() ?? '';
    final lastName = profile['lastName']?.toString().trim() ?? '';
    final extension = profile['extension']?.toString().trim() ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      return user.displayName ?? 'Trainer';
    }

    String middleInitial = '';
    if (middleName.isNotEmpty) {
      middleInitial = '${middleName[0].toUpperCase()}.';
    }

    final parts = [firstName, middleInitial, lastName, extension];
    final fullName = parts.where((p) => p.isNotEmpty).join(' ');

    return fullName.isNotEmpty ? fullName : 'Trainer';
  }

  // ✅ Helper method to calculate total students from all classes
  Future<int> _getTotalStudents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .get();

      int totalStudents = 0;
      for (final doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final classId = data['classId']?.toString() ?? '';
        if (classId.isNotEmpty) {
          final classDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(classId)
              .get();
          if (classDoc.exists) {
            final classData = classDoc.data() ?? {};
            final enrolledIds = List<String>.from(
              classData['enrolledStudentIds'] ?? [],
            );
            totalStudents += enrolledIds.length;
          }
        }
      }
      return totalStudents;
    } catch (e) {
      print('Error calculating total students: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0891B2);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No authenticated user found.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data?.data();
        final trainerName = _trainerName(profile, user);
        PersistentWorkspace.register(
          context,
          _TrainerDesktopNav(
            currentIndex: _selectedIndex,
            trainerName: trainerName,
            onChanged: (index) => PersistentWorkspace.returnHome(
              context,
              () => _selectTab(index),
            ),
            onNotifications: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NotificationPage())),
            onLogout: _logout,
          ),
        );

        return PopScope(
          canPop: _selectedIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _selectTab(0);
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F7FA),
            appBar: MediaQuery.sizeOf(context).width >= 1000
                ? null
                : AppBar(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    title: const Text(
                      "ICTEACH",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    actions: [
                      NotificationBadge(
                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationPage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Notifications',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _logout,
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final workspace = Column(
                  children: [
                    Material(
                      color: Colors.white,
                      child: SizedBox(
                        height: 76,
                        child: Row(
                          children: [
                            if (_selectedIndex != 0)
                              TextButton.icon(
                                onPressed: () => _selectTab(0),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Overview'),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                const [
                                  'Overview',
                                  'Discussions',
                                  'Profile',
                                  'Class Monitoring',
                                  'Feedback',
                                  'Student Management',
                                  'Module Management',
                                ][_selectedIndex],
                                style: const TextStyle(
                                  color: Color(0xFF102A43),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _buildHomeContent(
                            primaryColor,
                            trainerName,
                            user.uid,
                          ),
                          _buildDiscussionForums(primaryColor),
                          _buildProfileContent(profile, user),
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: const StaffOutcomes(trainer: true),
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: const StaffOutcomes(
                              trainer: true,
                              feedback: true,
                            ),
                          ),
                          const StaffManagementPage(trainer: true),
                          const StaffManagementPage(
                            modules: true,
                            trainer: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                if (constraints.maxWidth < 1000) return workspace;
                return Row(
                  children: [
                    _TrainerDesktopNav(
                      currentIndex: _selectedIndex,
                      trainerName: trainerName,
                      onChanged: (index) => _selectTab(index),
                      onNotifications: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationPage(),
                        ),
                      ),
                      onLogout: _logout,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: workspace),
                  ],
                );
              },
            ),
            bottomNavigationBar: MediaQuery.sizeOf(context).width >= 1000
                ? null
                : BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: _selectedIndex,
                    onTap: (index) => _selectTab(index),
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.forum_rounded),
                        label: 'Discussions',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.insights_outlined),
                        label: 'Class Monitoring',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.rate_review_outlined),
                        label: 'Feedback',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.groups_outlined),
                        label: 'Students',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.menu_book_outlined),
                        label: 'Modules',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHomeContent(
    Color primaryColor,
    String trainerName,
    String userId,
  ) {
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    return SingleChildScrollView(
      padding: desktop ? const EdgeInsets.all(22) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP BANNER
          if (desktop)
            const WorkspaceIntro(
              title: 'Build skills. Follow progress.',
              description:
                  'Manage learning activities, monitor your classes, and understand what helps students learn.',
            )
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF0F172A), Color(0xFF164E63)],
                ),
                borderRadius: desktop
                    ? BorderRadius.circular(20)
                    : const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                boxShadow: desktop
                    ? [
                        BoxShadow(
                          color: const Color(0xFF164E63).withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 44 : 20,
                vertical: desktop ? 29 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome back,",
                    style: TextStyle(color: Colors.white70, fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trainerName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: desktop ? 30 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF0891B2),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "OFFICIAL TRAINER",
                              style: TextStyle(
                                color: Color(0xFF0891B2),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "CSS Evaluator",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Padding(
            padding: EdgeInsets.fromLTRB(
              desktop ? 6 : 20,
              desktop ? 30 : 20,
              desktop ? 6 : 20,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(primaryColor),
                SizedBox(
                  height: MediaQuery.sizeOf(context).width >= 1000 ? 14 : 24,
                ),
                const Text(
                  'Trainer Tools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTrainerToolsGrid(primaryColor),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Dynamic stats row with actual student count
  Widget _buildStatsRow(Color primaryColor) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseAuth.instance.currentUser != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('classes')
                .get()
          : null,
      builder: (context, classSnapshot) {
        final classCount = classSnapshot.data?.docs.length ?? 0;

        return FutureBuilder<int>(
          future: _getTotalStudents(),
          builder: (context, studentSnapshot) {
            final totalStudents = studentSnapshot.data ?? 0;

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'My Classes',
                    '$classCount',
                    primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Students',
                    '$totalStudents',
                    primaryColor,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE7F1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerToolsGrid(Color primaryColor) {
    final items = [
      _TrainerToolItem(
        title: 'Training Modules',
        subtitle: 'Create & manage modules',
        icon: Icons.menu_book_rounded,
        color: Colors.deepPurple,
        bgColor: Colors.deepPurple.shade50,
        onTap: () => _showClassSelector(context, 'modules'),
      ),
      _TrainerToolItem(
        title: 'Instructional Videos',
        subtitle: 'Manage video resources',
        icon: Icons.video_library_rounded,
        color: Colors.purple,
        bgColor: Colors.purple.shade50,
        onTap: () => _showClassSelector(context, 'videos'),
      ),
      _TrainerToolItem(
        title: 'Quizzes & Assessments',
        subtitle: 'Create knowledge tests',
        icon: Icons.quiz_rounded,
        color: Colors.blue.shade800,
        bgColor: Colors.blue.shade50,
        onTap: () => _showClassSelector(context, 'quizzes'),
      ),
      _TrainerToolItem(
        title: 'Performance Activities',
        subtitle: 'Create & manage assignments',
        icon: Icons.assignment_rounded,
        color: Colors.indigo,
        bgColor: Colors.indigo.shade50,
        onTap: () => _showClassSelector(context, 'assignments'),
      ),
      _TrainerToolItem(
        title: 'Progress Tracker',
        subtitle: 'Monitor student progress',
        icon: Icons.analytics_rounded,
        color: Colors.teal.shade700,
        bgColor: Colors.teal.shade50,
        onTap: () => _showClassSelector(context, 'progress'),
      ),
      _TrainerToolItem(
        title: 'Competency Validation',
        subtitle: 'Evaluate trainee readiness',
        icon: Icons.verified_user_rounded,
        color: Colors.green.shade700,
        bgColor: Colors.green.shade50,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Competency Validation coming soon!'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: columns == 3 ? 1.75 : 1.15,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
          ),
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }

  // Discussion Forums Tab
  Widget _buildDiscussionForums(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('classes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final classDocs = snapshot.data?.docs ?? [];

        if (classDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No forums available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join a class to participate in discussions',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classDocs.length,
          itemBuilder: (context, index) {
            final doc = classDocs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final className =
                data['className']?.toString() ??
                data['name']?.toString() ??
                'Unnamed Class';
            final classId = data['classId']?.toString() ?? '';
            final teacherName =
                data['teacherName']?.toString() ?? 'Unknown Teacher';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.forum_rounded, color: primaryColor),
                ),
                title: Text(
                  className,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Teacher: $teacherName'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ForumsPage(classId: classId, className: className),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // Show Class Selector for Trainers
  void _showClassSelector(BuildContext context, String actionType) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('classes')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                  ],
                ),
              );
            }

            final classDocs = snapshot.data?.docs ?? [];

            if (classDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.class_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No classes joined',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join a class first to manage content',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinClassPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Join a Class'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            final actionTitle = actionType == 'modules'
                ? 'Modules'
                : actionType == 'quizzes'
                ? 'Quizzes'
                : actionType == 'assignments'
                ? 'Assignments'
                : actionType == 'progress'
                ? 'Progress'
                : 'Content';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        actionType == 'modules'
                            ? Icons.menu_book_rounded
                            : actionType == 'quizzes'
                            ? Icons.quiz_rounded
                            : actionType == 'assignments'
                            ? Icons.assignment_rounded
                            : actionType == 'progress'
                            ? Icons.analytics_rounded
                            : Icons.video_library_rounded,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage $actionTitle',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Select a class to manage',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: classDocs.length,
                    itemBuilder: (context, index) {
                      final doc = classDocs[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final className =
                          data['className']?.toString() ??
                          data['name']?.toString() ??
                          'Unnamed Class';
                      final classId = data['classId']?.toString() ?? '';
                      final teacherName =
                          data['teacherName']?.toString() ?? 'Unknown Teacher';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade100,
                            child: Icon(
                              actionType == 'modules'
                                  ? Icons.menu_book_rounded
                                  : actionType == 'quizzes'
                                  ? Icons.quiz_rounded
                                  : actionType == 'assignments'
                                  ? Icons.assignment_rounded
                                  : actionType == 'progress'
                                  ? Icons.analytics_rounded
                                  : Icons.video_library_rounded,
                              color: Colors.purple,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            className,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Teacher: $teacherName'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToAction(
                              context,
                              actionType,
                              classId,
                              className,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _navigateToAction(
    BuildContext context,
    String actionType,
    String classId,
    String className,
  ) {
    switch (actionType) {
      case 'modules':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ManageModulesPage(classId: classId, className: className),
          ),
        );
        break;
      case 'progress':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProgressTrackerPage(classId: classId, className: className),
          ),
        );
        break;
      case 'quizzes':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ManageQuizzesPage(classId: classId, className: className),
          ),
        );
        break;
      case 'assignments':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ManageAssignmentsPage(classId: classId, className: className),
          ),
        );
        break;
      case 'videos':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instructional Videos page coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$actionType management coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  Widget _buildProfileContent(Map<String, dynamic>? profile, User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.purple.shade100,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: Colors.purple,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  _trainerName(profile, user),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? 'No email',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'TESDA Trainer',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('classes')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final hasClass =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              final classDocs = snapshot.data?.docs ?? [];

              return Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.class_rounded,
                                color: Colors.purple,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Assigned Classes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (!hasClass)
                          GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const JoinClassPage(),
                                ),
                              );
                              if (result == true && mounted) {
                                setState(() {});
                              }
                            },
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
                              child: Text(
                                'Join Now',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasClass) ...[
                      ...classDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final className =
                            data['className']?.toString() ??
                            data['name']?.toString() ??
                            'Unnamed Class';
                        final teacherName =
                            data['teacherName']?.toString() ??
                            'Unknown Teacher';
                        final schoolYear = data['schoolYear']?.toString() ?? '';
                        final classId = data['classId']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.class_rounded,
                                      color: Colors.purple,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          className,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Teacher: $teacherName',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (schoolYear.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'School Year: $schoolYear',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (classId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ClassDetailPage(
                                            classId: classId,
                                            className: className,
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Class information not available',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                  ),
                                  label: const Text("View Class"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You haven\'t been assigned to a class yet. Join a class to start training students.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const JoinClassPage(),
                              ),
                            );
                            if (result == true && mounted) {
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Join a Class as Trainer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
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
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrainerToolItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _TrainerToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECE7F1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerDesktopNav extends StatelessWidget {
  const _TrainerDesktopNav({
    required this.currentIndex,
    required this.trainerName,
    required this.onChanged,
    required this.onLogout,
    required this.onNotifications,
  });
  final int currentIndex;
  final String trainerName;
  final ValueChanged<int> onChanged;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;
  @override
  Widget build(BuildContext context) => StaffSidebar(
    role: 'Trainer',
    name: trainerName,
    selectedIndex: currentIndex,
    items: const [
      (Icons.dashboard_outlined, 'Overview'),
      (Icons.forum_outlined, 'Discussions'),
      (Icons.person_outline, 'Profile'),
      (Icons.insights_outlined, 'Class Monitoring'),
      (Icons.rate_review_outlined, 'Feedback'),
      (Icons.groups_outlined, 'Student Management'),
      (Icons.menu_book_outlined, 'Module Management'),
    ],
    onSelected: onChanged,
    onLogout: onLogout,
    onNotifications: onNotifications,
  );
}
