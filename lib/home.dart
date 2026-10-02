import 'widgets/account_settings_section.dart';
import 'widgets/retained_future_builder.dart';
import 'widgets/lazy_indexed_stack.dart';
import 'services/workspace_data.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/student/student_questionnaires_page.dart';
import 'services/feedback_eligibility.dart';
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
import 'services/workspace_preferences.dart';
import 'services/student_achievement_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTabIndex = WorkspacePreferences.tab('student', 5);
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
      stream: WorkspaceData.profile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        final course =
            profile?['course'] as String? ??
            'CSS NC II - Computer System Servicing';

        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: WorkspaceData.activeMemberships(user.uid),
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
                // Modules and Forum own their headers once a class is available.
                appBar:
                    (_currentTabIndex == 1 || _currentTabIndex == 2) &&
                        _classId != null &&
                        _classId!.isNotEmpty
                    ? null
                    : _buildAppBar(),
                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: LazyIndexedStack(
                          index: _currentTabIndex,
                          children: [
                            () => _buildHomeContent(course, profile),
                            () => _buildModulesContent(),
                            () => _buildForumContent(),
                            () => _buildProgressContent(user.uid),
                            () => _buildProfileContent(profile, user),
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

  // Compact header for tabs without their own page header.
  PreferredSizeWidget _buildAppBar() => AppBar(
    automaticallyImplyLeading: false,
    leading: !kIsWeb && _currentTabIndex == 4
        ? BackButton(onPressed: () => _selectTab(0))
        : null,
    backgroundColor: const Color(0xFF428DEB),
    foregroundColor: Colors.white,
    title: Text(
      const [
        'Home',
        'Modules',
        'Forum',
        'Progress',
        'Profile',
      ][_currentTabIndex],
    ),
    actions: [
      NotificationBadge(
        child: IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationPage()),
          ),
        ),
      ),
    ],
  );

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

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: user != null ? WorkspaceData.activeMemberships(user.uid) : null,
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

  String _welcomeTitle(Map<String, dynamic>? profile) {
    final createdAt = profile?['createdAt'];
    final created = createdAt is Timestamp ? createdAt.toDate() : null;
    final isNew =
        created != null && DateTime.now().difference(created).inHours < 24;
    if (isNew) {
      final name = (profile?['firstName'] ?? profile?['displayName'])
          ?.toString()
          .trim();
      if (name != null && name.isNotEmpty) return 'Welcome, $name!';
      return 'Welcome!';
    }
    return 'Welcome Back';
  }

  Widget _buildHomeContent(String course, Map<String, dynamic>? profile) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
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
                      Text(
                        _welcomeTitle(profile),
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
          if (userId != null) ...[
            const SizedBox(height: 24),
            _buildHomeAchievementShelf(userId),
          ],
        ],
      ),
    );
  }

  Widget _buildHomeAchievementShelf(String userId) {
    if (_classId == null || _classId!.isEmpty) {
      return const SizedBox.shrink();
    }
    return RetainedFutureBuilder<List<StudentAchievement>>(
      requestKey: 'home-achievements:$userId:$_classId',
      active: _currentTabIndex == 0,
      load: () => StudentAchievementService().load(userId, _classId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final achievements = [...snapshot.data!]
          ..sort((a, b) {
            if (a.unlocked == b.unlocked) return 0;
            return a.unlocked ? -1 : 1;
          });
        final unlocked = achievements.where((item) => item.unlocked).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievement Badges',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Keep learning to unlock your collection',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3C4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$unlocked/${achievements.length}',
                    style: const TextStyle(
                      color: Color(0xFF8A5A00),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _HomeAchievementBadge(achievement: achievements[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressCard() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: user != null ? WorkspaceData.activeMemberships(user.uid) : null,
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

        return RetainedFutureBuilder<int>(
          requestKey: _classId,
          active: _currentTabIndex == 0,
          load: () => hasClass
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
    return RetainedFutureBuilder(
      requestKey: _classId,
      active: _currentTabIndex == 0,
      load: () => (_classId != null && _classId!.isNotEmpty)
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
          const Text(
            'My Progress',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          RetainedFutureBuilder<List<dynamic>>(
            requestKey: _classId,
            active: _currentTabIndex == 3,
            load: () => Future.wait([
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
          RetainedFutureBuilder<List<QuizResult>>(
            requestKey: _classId,
            active: _currentTabIndex == 3,
            load: () => _quizService.getStudentQuizResults(userId),
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
                RetainedFutureBuilder<List<Map<String, dynamic>>>(
                  requestKey: _classId,
                  active: _currentTabIndex == 3,
                  load: () => (_classId != null && _classId!.isNotEmpty)
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
                if (_classId == null)
                  const Text(
                    'Join or select a class to track achievements.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  RetainedFutureBuilder<List<StudentAchievement>>(
                    requestKey: 'achievements:$userId:$_classId',
                    active: _currentTabIndex == 3,
                    load: () =>
                        StudentAchievementService().load(userId, _classId!),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Achievements could not be loaded. Reopen this tab to retry.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: snapshot.data!
                            .map(_buildAchievementBadge)
                            .toList(),
                      );
                    },
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

  Widget _buildAchievementBadge(StudentAchievement achievement) {
    final unlocked = achievement.unlocked;
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFFFFF8E1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? const Color(0xFFFFC44D) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          AchievementMedal(achievement: achievement, size: 52),
          Text(
            unlocked ? achievement.icon : '🔒',
            style: const TextStyle(fontSize: 0),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: unlocked ? const Color(0xFF6B4E00) : null,
                  ),
                ),
                Text(
                  unlocked
                      ? 'Unlocked'
                      : '${achievement.description} · ${achievement.current}/${achievement.target}',
                  style: TextStyle(
                    color: unlocked
                        ? const Color(0xFF8A6500)
                        : Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Account details and account actions.
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
          AccountSettingsSection(
            email: user.email ?? '',
            role: 'student',
            accountDetails: {
              'Name': _getFullName(profile),
              'Email': user.email ?? 'No email',
              'Role': 'Student',
              'LRN': profile?['lrn']?.toString() ?? '',
              'Class': _className ?? '',
            },
            onLogout: _logout,
          ),
          const SizedBox(height: 8),

          if (FeedbackEligibility.isQualified(profile))
            Card(
              child: ListTile(
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text('System feedback'),
                subtitle: const Text('Share your experience with ICTeach'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('System feedback')),
                      body:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: WorkspaceData.profile(user.uid),
                            builder: (context, snapshot) =>
                                FeedbackEligibility.isQualified(
                                  snapshot.data?.data(),
                                )
                                ? const HelpfulnessSurvey()
                                : const SizedBox.shrink(),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          if (FeedbackEligibility.isQualified(profile) &&
              _classId != null &&
              _classId!.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('Class system evaluations'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentQuestionnairesPage(
                      classId: _classId!,
                      className: _className ?? 'My Class',
                      systemOnly: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final items = [
      {
        'icon': Icons.home_outlined,
        'selectedIcon': Icons.home_rounded,
        'label': 'Home',
        'index': 0,
      },
      {
        'icon': Icons.menu_book_outlined,
        'selectedIcon': Icons.menu_book_rounded,
        'label': 'Modules',
        'index': 1,
      },
      {
        'icon': Icons.forum_outlined,
        'selectedIcon': Icons.forum_rounded,
        'label': 'Forum',
        'index': 2,
      },
      {
        'icon': Icons.analytics_outlined,
        'selectedIcon': Icons.analytics_rounded,
        'label': 'Progress',
        'index': 3,
      },
      {
        'icon': Icons.person_outline_rounded,
        'selectedIcon': Icons.person_rounded,
        'label': 'Profile',
        'index': 4,
      },
    ];

    return Container(
      height: 76,
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
              width: MediaQuery.sizeOf(context).width / items.length,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.all(isSelected ? 8 : 5),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF428DEB), Color(0xFF2467B2)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF428DEB,
                                ).withValues(alpha: .24),
                                blurRadius: 9,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      (isSelected ? item['selectedIcon'] : item['icon'])
                          as IconData,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                      size: isSelected ? 22 : 24,
                    ),
                  ),
                  const SizedBox(height: 3),
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

class _HomeAchievementBadge extends StatelessWidget {
  const _HomeAchievementBadge({required this.achievement});
  final StudentAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Container(
      width: 152,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? const Color(0xFFF6C453) : const Color(0xFFE2E8F0),
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          AchievementMedal(achievement: achievement, size: 66),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unlocked
                ? 'Unlocked'
                : '${achievement.current}/${achievement.target} progress',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: unlocked
                  ? const Color(0xFFB45309)
                  : const Color(0xFF64748B),
            ),
          ),
          if (!unlocked) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: achievement.progress,
                minHeight: 4,
                color: const Color(0xFF64748B),
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AchievementMedal extends StatelessWidget {
  const AchievementMedal({
    super.key,
    required this.achievement,
    this.size = 60,
  });
  final StudentAchievement achievement;
  final double size;

  (IconData, Color, Color) get _style => switch (achievement.title) {
    'Ready to Learn' => (
      Icons.explore_rounded,
      const Color(0xFF2563EB),
      const Color(0xFF60A5FA),
    ),
    'First Quiz' => (
      Icons.quiz_rounded,
      const Color(0xFF7C3AED),
      const Color(0xFFA78BFA),
    ),
    'Quiz Explorer' => (
      Icons.auto_awesome_rounded,
      const Color(0xFF9333EA),
      const Color(0xFFD8B4FE),
    ),
    'Module Starter' => (
      Icons.menu_book_rounded,
      const Color(0xFF0891B2),
      const Color(0xFF67E8F9),
    ),
    'Module Master' => (
      Icons.library_books_rounded,
      const Color(0xFF0D9488),
      const Color(0xFF5EEAD4),
    ),
    'Learning Champion' => (
      Icons.workspace_premium_rounded,
      const Color(0xFFD97706),
      const Color(0xFFFCD34D),
    ),
    'High Achiever' => (
      Icons.military_tech_rounded,
      const Color(0xFFEA580C),
      const Color(0xFFFDBA74),
    ),
    'Perfect Score' => (
      Icons.gps_fixed_rounded,
      const Color(0xFFDC2626),
      const Color(0xFFFCA5A5),
    ),
    'Simulation Rookie' => (
      Icons.build_circle_rounded,
      const Color(0xFF475569),
      const Color(0xFF94A3B8),
    ),
    'Tech Explorer' => (
      Icons.memory_rounded,
      const Color(0xFF0284C7),
      const Color(0xFF7DD3FC),
    ),
    _ => (
      Icons.shield_rounded,
      const Color(0xFF16A34A),
      const Color(0xFF86EFAC),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final style = _style;
    final primary = unlocked ? style.$2 : const Color(0xFF94A3B8);
    final secondary = unlocked ? style.$3 : const Color(0xFFCBD5E1);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [secondary, primary],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: .24),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              unlocked ? style.$1 : Icons.lock_rounded,
              color: Colors.white,
              size: size * .42,
            ),
          ),
          if (unlocked)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(size * .055),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD54F),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: const Color(0xFF7C4A00),
                  size: size * .2,
                ),
              ),
            ),
        ],
      ),
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
