import 'widgets/summary_print_button.dart';
import 'services/personal_summary_service.dart';
import 'widgets/persistent_workspace.dart';
import 'screens/student/helpfulness_survey.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:icteach/screens/student/forums_page.dart';
import 'package:icteach/screens/student/module_view_page.dart';
import 'package:icteach/screens/student/student_assignments_page.dart';
import 'package:icteach/screens/student/student_quizzes_page.dart';
import 'package:icteach/screens/student/instructional_videos_page.dart';
import 'package:icteach/screens/student/simulations_list_page.dart';
import 'package:icteach/screens/notification_page.dart';
import 'package:icteach/widgets/notification_badge.dart';
import 'join_class.dart';
import 'class_detail_page.dart';
import 'login.dart';
import '../../services/quiz_service.dart';
import '../../models/quiz_model.dart';
import '../../services/module_service.dart';
import 'package:icteach/utils/progress_calculator.dart';
import 'package:intl/intl.dart';
import 'widgets/leaderboard_chart.dart';
import 'data/simulation_data.dart';
import 'data/pre_assessment_data.dart';
import 'services/school_year_service.dart';
import 'widgets/user_roles_button.dart';
import 'services/workspace_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTabIndex = WorkspacePreferences.tab('student', 6);
  void _selectTab(int index) {
    setState(() => _currentTabIndex = index);
    WorkspacePreferences.saveTab('student', index);
  }

  String? _classId;
  String? _className;
  final QuizService _quizService = QuizService();

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
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No student signed in.')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        final fullName = _getFullName(profile);
        final course =
            profile?['course'] as String? ??
            'CSS NC II - Computer System Servicing';

        return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          future: SchoolYearService.activeMemberships(user.uid),
          builder: (context, classSnapshot) {
            _classId = null;
            _className = null;
            if (classSnapshot.hasData && classSnapshot.data!.isNotEmpty) {
              final doc = classSnapshot.data!.first;
              final data = doc.data() as Map<String, dynamic>?;
              if (data != null) {
                _classId = data['classId']?.toString() ?? '';
                _className = data['className']?.toString() ?? 'My Class';
              }
            }

            return PopScope(
              // Allow pop only when on the home tab (tab 0) so the
              // exit dialog in home_router.dart can handle it.
              canPop: _currentTabIndex == 0,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                // Not on home tab → go back to home tab
                _selectTab(0);
              },
              child: Scaffold(
                backgroundColor: const Color(0xFFF4F7FA),
                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _buildHeader(fullName, user.photoURL),
                      Expanded(
                        child: IndexedStack(
                          index: _currentTabIndex,
                          children: [
                            _buildHomeContent(course),
                            _buildModulesContent(),
                            _buildForumContent(),
                            _buildProgressContent(user.uid),
                            _buildProfileContent(profile, user),
                            const HelpfulnessSurvey(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: _buildBottomNavBar(),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ UPDATED HEADER WITH NOTIFICATION BADGE
  Widget _buildHeader(String name, String? photoUrl) {
    final timeOfDay = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (timeOfDay >= 12 && timeOfDay < 17) {
      greeting = 'Good Afternoon';
    } else if (timeOfDay >= 17) {
      greeting = 'Good Evening';
    }

    return Container(
      height: 130,
      width: double.infinity,
      color: const Color(0xFF428DEB),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Row(
        children: [
          const UserRolesButton(),
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            child: photoUrl == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF428DEB),
                    size: 32,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // ✅ NOTIFICATION BADGE WITH ICON
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
                size: 26,
              ),
              tooltip: 'Notifications',
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 26,
            ),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Forum Content Tab
  Widget _buildForumContent() {
    if (_classId == null || _classId!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Class Joined',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Join a class to access discussion forums',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinClassPage()),
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Join a Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF428DEB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ForumsPage(classId: _classId!, className: _className ?? 'My Class');
  }

  // Modules Tab Content
  Widget _buildModulesContent() {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: user != null
          ? SchoolYearService.activeMemberships(user.uid)
          : null,
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
              ],
            ),
          );
        }

        final classDocs = snapshot.data ?? [];

        if (classDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Class Joined',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join a class to access learning modules',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinClassPage()),
                    );
                    if (result == true && mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Join a Class'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF428DEB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        final classDoc = classDocs.first;
        final data = classDoc.data() as Map<String, dynamic>?;
        final classId = data?['classId']?.toString() ?? '';
        final className = data?['className']?.toString() ?? 'My Class';

        return ModuleViewPage(classId: classId, className: className);
      },
    );
  }

  Widget _buildHomeContent(String course) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 70,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: -8,
                  top: -30,
                  child: _buildHeartMascot(size: 85),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildProgressCard(),
          const SizedBox(height: 24),
          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickAccessGrid(),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: user != null
          ? SchoolYearService.activeMemberships(user.uid)
          : null,
      builder: (context, snapshot) {
        final hasClass = snapshot.hasData && snapshot.data!.isNotEmpty;

        String className = 'No Class Joined';
        String schoolYear = '';
        String classId = '';

        if (hasClass) {
          final doc = snapshot.data!.first;
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            className =
                data['className']?.toString() ??
                data['name']?.toString() ??
                'Your Class';
            schoolYear = data['schoolYear']?.toString() ?? '';
            classId = data['classId']?.toString() ?? '';
          }
        }

        return FutureBuilder<int>(
          future: hasClass
              ? ModuleService().getModuleCount(classId)
              : Future.value(0),
          builder: (context, moduleSnap) {
            final moduleCount = moduleSnap.data ?? 0;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
                              color: const Color(0xFF428DEB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Color(0xFF428DEB),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasClass ? 'Current Class' : 'Get Started',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                className,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              if (schoolYear.isNotEmpty)
                                Text(
                                  'SY: $schoolYear',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                            ],
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
                            if (result == true && context.mounted) {
                              setState(() {});
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'Join Now',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: hasClass && moduleCount > 0 ? 1.0 : 0.0,
                      color: const Color(0xFF428DEB),
                      backgroundColor: const Color(0xFFE5E7EB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasClass
                            ? '$moduleCount modules available'
                            : 'Join a class to start learning',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      if (hasClass)
                        TextButton(
                          onPressed: () {
                            _navigateToClass(context, classId, className);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Go to Class →',
                            style: TextStyle(
                              color: Color(0xFF428DEB),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToClass(
    BuildContext context,
    String classId,
    String className,
  ) {
    if (classId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class information not available')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassDetailPage(classId: classId, className: className),
      ),
    );
  }

  Future<void> _navigateToInstructionalVideos(BuildContext context) async {
    if (_classId == null || _classId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please join a class first to access videos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            InstructionalVideosPage(classId: _classId, className: _className),
      ),
    );
  }

  // ✅ Updated Quick Access Grid with Quizzes
  Widget _buildQuickAccessGrid() {
    return FutureBuilder(
      future: (_classId != null && _classId!.isNotEmpty)
          ? Future.wait([
              ModuleService().getModuleCount(_classId!),
              _quizService
                  .getPublishedQuizzesForClass(_classId!)
                  .first
                  .then((q) => q.length),
            ])
          : Future.value([0, 0]),
      builder: (context, AsyncSnapshot<List<int>> snapshot) {
        final moduleCount = snapshot.data?[0] ?? 0;
        final quizCount = snapshot.data?[1] ?? 0;

        final items = [
          _QuickAccessItem(
            icon: Icons.menu_book_rounded,
            title: 'Learning Modules',
            subtitle: '$moduleCount modules',
            color: const Color(0xFF4F6DB8),
            bgColor: const Color(0xFFDCE6FF),
            onTap: () {
              _selectTab(1);
            },
          ),
          _QuickAccessItem(
            icon: Icons.quiz_rounded,
            title: 'Quizzes',
            subtitle: '$quizCount available',
            color: const Color(0xFF9C4FA1),
            bgColor: const Color(0xFFE9C4EB),
            onTap: () {
              if (_classId != null && _classId!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentQuizzesPage(
                      classId: _classId!,
                      className: _className ?? 'My Class',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please join a class first to access quizzes',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
          _QuickAccessItem(
            icon: Icons.assignment_rounded,
            title: 'Assignments',
            subtitle: 'View assignments',
            color: const Color(0xFFE76C31),
            bgColor: const Color(0xFFFFD7C2),
            onTap: () {
              if (_classId != null && _classId!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentAssignmentsPage(
                      classId: _classId!,
                      className: _className ?? 'My Class',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please join a class first to access assignments',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
          _QuickAccessItem(
            icon: Icons.science_rounded,
            title: 'Simulations',
            subtitle: 'Interactive Labs',
            color: const Color(0xFF168D92),
            bgColor: const Color(0xFFA6F4F5),
            onTap: () {
              if (_classId != null && _classId!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SimulationsListPage(
                      classId: _classId!,
                      className: _className ?? 'My Class',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please join a class first to access simulations',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
          _QuickAccessItem(
            icon: Icons.video_library_rounded,
            title: 'Videos',
            subtitle: 'Video Lessons',
            color: const Color(0xFFD97847),
            bgColor: const Color(0xFFFFCFB1),
            onTap: () {
              _navigateToInstructionalVideos(context);
            },
          ),
          _QuickAccessItem(
            icon: Icons.forum_rounded,
            title: 'Forums',
            subtitle: 'Join Discussion',
            color: const Color(0xFF249A38),
            bgColor: const Color(0xFFC9F2CE),
            onTap: () {
              if (_classId != null && _classId!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ForumsPage(
                      classId: _classId!,
                      className: _className ?? 'My Class',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please join a class first to access forums'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ];

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }

  // ✅ Updated Progress Content with QuizService
  Widget _buildProgressContent(String userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryPrintButton(
            title: 'My learning summary',
            load: () => PersonalSummaryService.load(userId, classId: _classId),
          ),
          const Text(
            'My Progress',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<dynamic>>(
            future: Future.wait([
              (_classId != null && _classId!.isNotEmpty)
                  ? _quizService.getStudentQuizResultsForClass(
                      userId,
                      _classId!,
                    )
                  : _quizService.getStudentQuizResults(userId),
              (_classId != null && _classId!.isNotEmpty)
                  ? _quizService
                        .getPublishedQuizzesForClass(_classId!)
                        .first
                        .then((q) => q.map((item) => item.id).toSet())
                  : Future.value(<String>{}),
              (_classId != null && _classId!.isNotEmpty)
                  ? ModuleService()
                        .getPublishedModulesForClass(_classId!)
                        .first
                        .then(
                          (modules) => modules.map((item) => item.id).toSet(),
                        )
                  : Future.value(<String>{}),
              Future.value(
                _classId == null
                    ? 0
                    : SimulationData.getAllSimulations().length,
              ),
              Future.value(_classId == null ? 0 : 1),
              _classId == null
                  ? Future.value(<String>{})
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('module_progress')
                        .where('classId', isEqualTo: _classId)
                        .get()
                        .then(
                          (s) => s.docs
                              .where((d) => d.data()['completed'] == true)
                              .map((d) => d.data()['moduleId'].toString())
                              .toSet(),
                        ),
              _classId == null
                  ? Future.value(<String>{})
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('simulation_progress')
                        .where('classId', isEqualTo: _classId)
                        .get()
                        .then(
                          (s) => s.docs
                              .where(
                                (d) =>
                                    d.data()['completed'] == true &&
                                    d.data()['passed'] == true,
                              )
                              .map((d) => d.data()['simulationId'].toString())
                              .toSet(),
                        ),
              _classId == null
                  ? Future.value(0)
                  : FirebaseFirestore.instance
                        .collection('pre_assessments')
                        .doc('${userId}_$_classId')
                        .get()
                        .then(
                          (d) => PreAssessmentData.isComplete(d.data()) ? 1 : 0,
                        ),
            ]),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Progress could not be loaded. Reconnect and reopen this tab.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final quizResults =
                  (snapshot.data?[0] as List<QuizResult>?) ?? [];
              final quizIds = (snapshot.data?[1] as Set<String>?) ?? <String>{};
              final moduleIds =
                  (snapshot.data?[2] as Set<String>?) ?? <String>{};
              final totalQuizzes = quizIds.length;
              final totalModules = moduleIds.length;
              final simulationTotal = (snapshot.data?[3] as int?) ?? 0;
              final assessmentTotal = (snapshot.data?[4] as int?) ?? 0;

              final quizCompleted = quizResults
                  .map((r) => r.quizId)
                  .toSet()
                  .intersection(quizIds)
                  .length;
              final moduleCompleted =
                  ((snapshot.data?[5] as Set<String>?) ?? <String>{})
                      .intersection(moduleIds)
                      .length;
              final simulationCompleted =
                  ((snapshot.data?[6] as Set<String>?) ?? <String>{})
                      .intersection(
                        SimulationData.getAllSimulations()
                            .map((s) => s.id)
                            .toSet(),
                      )
                      .length;
              final assessmentCompleted = (snapshot.data?[7] as int?) ?? 0;

              final stats = ProgressCalculator.calculate(
                quizCompleted: quizCompleted,
                quizTotal: totalQuizzes,
                moduleCompleted: moduleCompleted,
                moduleTotal: totalModules,
                simulationCompleted: simulationCompleted,
                simulationTotal: simulationTotal,
                assessmentCompleted: assessmentCompleted,
                assessmentTotal: assessmentTotal,
              );

              final avgScore = quizResults.isNotEmpty
                  ? quizResults.fold<double>(
                          0,
                          (sum, r) => sum + r.percentage,
                        ) /
                        quizResults.length
                  : 0;

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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildProgressStat(
                          'Quiz',
                          '$quizCompleted/$totalQuizzes',
                          '${stats.quizPercent.toStringAsFixed(0)}%',
                        ),
                        _buildProgressStat(
                          'Modules',
                          '$moduleCompleted/$totalModules',
                          '${stats.modulePercent.toStringAsFixed(0)}%',
                        ),
                        _buildProgressStat(
                          'Simulation',
                          '$simulationCompleted/$simulationTotal',
                          '${stats.simulationPercent.toStringAsFixed(0)}%',
                        ),
                        _buildProgressStat(
                          'Assessment',
                          '$assessmentCompleted/$assessmentTotal',
                          '${stats.assessmentPercent.toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Overall Progress: ${stats.overallPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF428DEB),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: (stats.overallPercent / 100).clamp(0.0, 1.0),
                        color: const Color(0xFF428DEB),
                        backgroundColor: const Color(0xFFE5E7EB),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Average quiz score: ${avgScore > 0 ? avgScore.toStringAsFixed(0) : 0}%',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<QuizResult>>(
            future: _quizService.getStudentQuizResults(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final results = snapshot.data ?? [];
              if (results.isEmpty) {
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
                  child: const Column(
                    children: [
                      Icon(Icons.quiz_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No quizzes taken yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

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
                    const Text(
                      'Quiz Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...results.map((result) => _buildQuizResultTile(result)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
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
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: 8),
                    const Text(
                      'Leaderboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Top 3',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: (_classId != null && _classId!.isNotEmpty)
                      ? _quizService.getClassLeaderboard(_classId!)
                      : Future.value([]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final leaderboard = snapshot.data ?? [];

                    if (leaderboard.isEmpty) {
                      return const Center(
                        child: Text(
                          'No leaderboard data yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return LeaderboardChart(entries: leaderboard);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
                  'Achievements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildAchievementBadge(
                      '🏆',
                      'First Quiz',
                      'Completed your first quiz',
                    ),
                    _buildAchievementBadge(
                      '⭐',
                      'Module Master',
                      'Completed 3 modules',
                    ),
                    _buildAchievementBadge(
                      '🎯',
                      'Perfect Score',
                      'Got 100% on a quiz',
                    ),
                    _buildAchievementBadge(
                      '🔧',
                      'Tech Explorer',
                      'Completed 2 simulations',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizResultTile(QuizResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: result.isPassed
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              result.isPassed ? Icons.check_circle : Icons.cancel,
              color: result.isPassed ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Knowledge Assessment',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Completed on ${DateFormat.yMMMd().format(result.completedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score: ${result.score}/${result.totalPoints} (${result.percentage.toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: result.isPassed
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              result.isPassed ? 'Passed' : 'Failed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: result.isPassed
                    ? Colors.green.shade800
                    : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, String percentage) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF428DEB),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF428DEB).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            percentage,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF428DEB),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(String emoji, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: Profile Content with Debug Tools
  Widget _buildProfileContent(Map<String, dynamic>? profile, User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Card
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
                  backgroundColor: const Color(
                    0xFF428DEB,
                  ).withValues(alpha: 0.1),
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: Color(0xFF428DEB),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  _getFullName(profile),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? 'No email',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF428DEB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Student',
                    style: TextStyle(
                      color: Color(0xFF428DEB),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Class Info Card
          FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: SchoolYearService.activeMemberships(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final hasClass = snapshot.hasData && snapshot.data!.isNotEmpty;

              String className = '';
              String teacherName = '';
              String schoolYear = '';
              String classId = '';

              if (hasClass) {
                final doc = snapshot.data!.first;
                final data = doc.data() as Map<String, dynamic>?;
                if (data != null) {
                  className =
                      data['className']?.toString() ??
                      data['name']?.toString() ??
                      '';
                  teacherName = data['teacherName']?.toString() ?? '';
                  schoolYear = data['schoolYear']?.toString() ?? '';
                  classId = data['classId']?.toString() ?? '';
                }
              }

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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF428DEB,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.class_rounded,
                            color: Color(0xFF428DEB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'My Class',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasClass) ...[
                      Text(
                        className.isNotEmpty ? className : 'No Class Name',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Teacher: ${teacherName.isNotEmpty ? teacherName : "Unknown"}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (schoolYear.isNotEmpty)
                        Text(
                          'School Year: $schoolYear',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _navigateToClass(context, classId, className);
                          },
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text("Go to Class"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF428DEB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
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
                                'You haven\'t joined a class yet.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w500,
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
                            if (result == true && context.mounted) {
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Join a Class'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF428DEB),
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

          // ✅ ADDED: Debug Tools Section
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final items = [
      {'icon': Icons.home_outlined, 'label': 'Home', 'index': 0},
      {'icon': Icons.menu_book_outlined, 'label': 'Modules', 'index': 1},
      {'icon': Icons.forum_outlined, 'label': 'Forum', 'index': 2},
      {'icon': Icons.bar_chart_rounded, 'label': 'Progress', 'index': 3},
      {'icon': Icons.person_outline_rounded, 'label': 'Profile', 'index': 4},
      {'icon': Icons.rate_review_outlined, 'label': 'Feedback', 'index': 5},
    ];

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final index = item['index'] as int;
          final isSelected = _currentTabIndex == index;
          return InkWell(
            onTap: () => _selectTab(index),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width / 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: isSelected
                        ? const Color(0xFF428DEB)
                        : Colors.grey.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF428DEB)
                          : Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF428DEB),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFullName(Map<String, dynamic>? profile) {
    if (profile == null) {
      final user = FirebaseAuth.instance.currentUser;
      return user?.displayName ?? 'Student';
    }

    final firstName = profile['firstName']?.toString().trim() ?? '';
    final middleName = profile['middleName']?.toString().trim() ?? '';
    final lastName = profile['lastName']?.toString().trim() ?? '';
    final extension = profile['extension']?.toString().trim() ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      return user?.displayName ?? 'Student';
    }

    String middleInitial = '';
    if (middleName.isNotEmpty) {
      middleInitial = '${middleName[0].toUpperCase()}.';
    }

    final parts = [firstName, middleInitial, lastName, extension];
    final fullName = parts.where((p) => p.isNotEmpty).join(' ');

    return fullName.isNotEmpty ? fullName : 'Student';
  }

  Widget _buildHeartMascot({required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HeartMascotPainter()),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                fontSize: 14,
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

class _HeartMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 85;
    canvas.scale(scale);

    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final heartFill = Paint()
      ..color = const Color(0xFFFF2F69)
      ..style = PaintingStyle.fill;
    final whiteFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shoeFill = Paint()
      ..color = const Color(0xFF2677D8)
      ..style = PaintingStyle.fill;

    final heart = Path()
      ..moveTo(42, 26)
      ..cubicTo(37, 13, 16, 14, 15, 33)
      ..cubicTo(14, 49, 32, 59, 42, 70)
      ..cubicTo(52, 59, 70, 49, 69, 33)
      ..cubicTo(68, 14, 47, 13, 42, 26)
      ..close();
    canvas.drawPath(heart, heartFill);
    canvas.drawPath(heart, outline);

    canvas.drawCircle(const Offset(34, 36), 10, whiteFill);
    canvas.drawCircle(const Offset(50, 36), 10, whiteFill);
    canvas.drawCircle(const Offset(36, 37), 3.5, Paint()..color = Colors.black);
    canvas.drawCircle(const Offset(48, 37), 3.5, Paint()..color = Colors.black);

    final smile = Path()
      ..moveTo(34, 49)
      ..quadraticBezierTo(42, 55, 50, 49);
    canvas.drawPath(smile, outline);

    canvas.drawLine(const Offset(17, 43), const Offset(4, 33), outline);
    canvas.drawLine(const Offset(67, 43), const Offset(80, 32), outline);
    canvas.drawCircle(const Offset(4, 33), 3.5, whiteFill);
    canvas.drawCircle(const Offset(80, 32), 3.5, whiteFill);
    canvas.drawCircle(const Offset(4, 33), 3.5, outline);
    canvas.drawCircle(const Offset(80, 32), 3.5, outline);

    canvas.drawLine(const Offset(35, 67), const Offset(30, 80), outline);
    canvas.drawLine(const Offset(49, 67), const Offset(56, 80), outline);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(25, 81), width: 17, height: 6),
      shoeFill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(61, 81), width: 17, height: 6),
      shoeFill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(25, 81), width: 17, height: 6),
      outline,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(61, 81), width: 17, height: 6),
      outline,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
