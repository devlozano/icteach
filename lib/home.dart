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
  String _classSchoolYear = '';
  bool _classArchived = false;
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
          stream: WorkspaceData.studentClasses(user.uid),
          builder: (context, classSnapshot) {
            _classId = null;
            _className = null;
            _classSchoolYear = '';
            _classArchived = false;
            if (classSnapshot.hasData && classSnapshot.data!.isNotEmpty) {
              final doc = classSnapshot.data!.first;
              final data = doc.data() as Map<String, dynamic>?;
              if (data != null) {
                _classId = doc.id;
                _className =
                    data['className']?.toString() ??
                    data['name']?.toString() ??
                    'My Class';
                _classSchoolYear = data['schoolYear']?.toString() ?? '';
                _classArchived = data['status'] == 'archived';
              }
            }

            return PopScope(
              // Allow pop only when on the home tab (tab 0) so the
              // exit dialog in home_router.dart can handle it.
              canPop: _currentTabIndex == 0,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                // Return to the home tab before leaving the student workspace.
                _selectTab(0);
              },
              child: Scaffold(
                backgroundColor: _currentTabIndex == 0
                    ? const Color(0xFFEEF7FF)
                    : const Color(0xFFF4F7FA),
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
    elevation: _currentTabIndex == 0 ? 0 : 4,
    toolbarHeight: kToolbarHeight,
    flexibleSpace: _currentTabIndex == 0
        ? Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1565D8),
                      Color(0xFF2F8FF0),
                      Color(0xFF64C4F4),
                    ],
                    stops: [0, .58, 1],
                  ),
                ),
              ),
              Positioned(
                right: 38,
                top: -42,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .10),
                  ),
                ),
              ),
              Positioned(
                right: 118,
                bottom: -46,
                child: Transform.rotate(
                  angle: -.32,
                  child: Container(
                    width: 132,
                    height: 74,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: const Color(0xFFBDEBFF).withValues(alpha: .17),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 128,
                top: -34,
                child: Transform.rotate(
                  angle: .28,
                  child: Container(
                    width: 86,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFF8BE0FF).withValues(alpha: .16),
                    ),
                  ),
                ),
              ),
            ],
          )
        : null,
    foregroundColor: Colors.white,
    title: Text(
      const [
        'Home',
        'Modules',
        'Forum',
        'Progress',
        'Profile',
      ][_currentTabIndex],
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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

    return ForumsPage(
      classId: _classId!,
      className: _className ?? 'My Class',
      readOnly: _classArchived,
    );
  }

  // Modules Tab Content
  Widget _buildModulesContent() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _classId == null || _classId!.isEmpty) {
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
    return ModuleViewPage(
      classId: _classId!,
      className: _className ?? 'My Class',
      readOnly: _classArchived,
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
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _StudentHomeBackgroundPainter()),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 126,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 2,
                          right: 94,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _welcomeTitle(profile),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 28,
                                  height: 1.04,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF071739),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                course,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF52657F),
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 4,
                          child: _buildHeartMascot(size: 94),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildProgressCard(),
                  const SizedBox(height: 18),
                  const _HomeSectionHeading(title: 'Quick Access'),
                  const SizedBox(height: 13),
                  _buildQuickAccessGrid(),
                  const SizedBox(height: 26),
                  _buildHomeAchievements(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeAchievements() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _classId == null || _classId!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: _HomeSectionHeading(title: 'Achievements')),
              AchievementUnlockCount(unlocked: 0, total: 0),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD7E9F8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: Color(0xFF428DEB)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Join or select a class to start earning achievements.',
                    style: TextStyle(
                      color: Color(0xFF52657F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return RetainedFutureBuilder<List<StudentAchievement>>(
      requestKey: 'home-achievements:${user.uid}:$_classId',
      active: _currentTabIndex == 0,
      load: () => StudentAchievementService().load(user.uid, _classId!),
      builder: (context, snapshot) {
        final achievements = snapshot.data ?? const <StudentAchievement>[];
        final unlocked = achievements.where((item) => item.unlocked).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _HomeSectionHeading(title: 'Achievements'),
                ),
                AchievementUnlockCount(
                  unlocked: unlocked,
                  total: achievements.length,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (snapshot.hasError)
              const Text(
                'Achievements could not be loaded right now.',
                style: TextStyle(color: Color(0xFF64748B)),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                height: 164,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: achievements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => SizedBox(
                    width: 136,
                    child: _buildAchievementBadge(achievements[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<double> _loadOverallProgress(String userId, String classId) async {
    final results = await Future.wait<dynamic>([
      _quizService.getStudentQuizResultsForClass(userId, classId),
      _quizService
          .getPublishedQuizzesForClass(classId)
          .first
          .then((items) => items.map((item) => item.id).toSet()),
      ModuleService()
          .getPublishedModulesForClass(classId)
          .first
          .then((items) => items.map((item) => item.id).toSet()),
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('module_progress')
          .where('classId', isEqualTo: classId)
          .get()
          .then(
            (snapshot) => snapshot.docs
                .where((doc) => doc.data()['completed'] == true)
                .map((doc) => doc.data()['moduleId'].toString())
                .toSet(),
          ),
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('simulation_progress')
          .where('classId', isEqualTo: classId)
          .get()
          .then(
            (snapshot) => snapshot.docs
                .where(
                  (doc) =>
                      doc.data()['completed'] == true &&
                      doc.data()['passed'] == true,
                )
                .map((doc) => doc.data()['simulationId'].toString())
                .toSet(),
          ),
      FirebaseFirestore.instance
          .collection('pre_assessments')
          .doc('${userId}_$classId')
          .get()
          .then((doc) => PreAssessmentData.isComplete(doc.data()) ? 1 : 0),
    ]);

    final quizResults = results[0] as List<QuizResult>;
    final quizIds = results[1] as Set<String>;
    final moduleIds = results[2] as Set<String>;
    final completedModuleIds = results[3] as Set<String>;
    final completedSimulationIds = results[4] as Set<String>;
    final simulationIds = SimulationData.getAllSimulations()
        .map((simulation) => simulation.id)
        .toSet();

    return ProgressCalculator.calculate(
      quizCompleted: quizResults
          .map((result) => result.quizId)
          .toSet()
          .intersection(quizIds)
          .length,
      quizTotal: quizIds.length,
      moduleCompleted: completedModuleIds.intersection(moduleIds).length,
      moduleTotal: moduleIds.length,
      simulationCompleted: completedSimulationIds
          .intersection(simulationIds)
          .length,
      simulationTotal: simulationIds.length,
      assessmentCompleted: results[5] as int,
      assessmentTotal: 1,
    ).overallPercent;
  }

  Widget _buildProgressCard() {
    final user = FirebaseAuth.instance.currentUser;

    final hasClass = _classId != null && _classId!.isNotEmpty;
    final className = hasClass
        ? (_className ?? 'Your Class')
        : 'No Class Joined';
    final schoolYear = _classSchoolYear;
    final classId = _classId ?? '';
    return RetainedFutureBuilder<double>(
      requestKey: 'home-overall:${user?.uid}:$classId',
      active: _currentTabIndex == 0,
      load: () => hasClass && user != null
          ? _loadOverallProgress(user.uid, classId)
          : Future.value(0),
      builder: (context, progressSnap) {
        final overallPercent = progressSnap.data ?? 0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD7E9F8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF397EB7).withValues(alpha: .12),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Color(0xFF2E8EF0),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasClass ? 'Current Class' : 'Get Started',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF667085),
                          ),
                        ),
                        Text(
                          className,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0B1735),
                          ),
                        ),
                        if (schoolYear.isNotEmpty)
                          Text(
                            'SY: $schoolYear',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                      ],
                    ),
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: hasClass
                      ? (overallPercent / 100).clamp(0.0, 1.0)
                      : 0.0,
                  color: const Color(0xFF428DEB),
                  backgroundColor: const Color(0xFFE5E7EB),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF2E8EF0),
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      hasClass
                          ? '${overallPercent.toStringAsFixed(0)}% overall progress'
                          : 'Join a class to start learning',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasClass)
                    FilledButton(
                      onPressed: () {
                        _navigateToClass(context, classId, className);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE7F3FF),
                        foregroundColor: const Color(0xFF1677D2),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Go to Class',
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

  // Student quick-access destinations.
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
                      readOnly: _classArchived,
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
                      readOnly: _classArchived,
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
                      practiceOnly: _classArchived,
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
            icon: Icons.groups_rounded,
            title: 'Forums',
            subtitle: 'Join discussions',
            color: const Color(0xFFD9468B),
            bgColor: const Color(0xFFFFC7E1),
            onTap: () {
              if (_classId != null && _classId!.isNotEmpty) {
                _selectTab(2);
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
          _QuickAccessItem(
            icon: Icons.bar_chart_rounded,
            title: 'Progress',
            subtitle: 'Track your progress',
            color: const Color(0xFF249A38),
            bgColor: const Color(0xFFC9F2CE),
            onTap: () => _selectTab(3),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 900 ? 3 : 2,
              childAspectRatio: constraints.maxWidth < 430 ? 1.72 : 2.05,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) => items[index],
          ),
        );
      },
    );
  }

  // Student progress details.
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
                          'Assignment',
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
                if (_classId == null)
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Achievements',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          AchievementUnlockCount(unlocked: 0, total: 0),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Join or select a class to track achievements.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                else
                  RetainedFutureBuilder<List<StudentAchievement>>(
                    requestKey: 'achievements:$userId:$_classId',
                    active: _currentTabIndex == 3,
                    load: () =>
                        StudentAchievementService().load(userId, _classId!),
                    builder: (context, snapshot) {
                      final achievements =
                          snapshot.data ?? const <StudentAchievement>[];
                      final unlocked = achievements
                          .where((item) => item.unlocked)
                          .length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Achievements',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              AchievementUnlockCount(
                                unlocked: unlocked,
                                total: achievements.length,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (snapshot.hasError)
                            const Text(
                              'Achievements could not be loaded. Reopen this tab to retry.',
                            )
                          else if (!snapshot.hasData)
                            const Center(child: CircularProgressIndicator())
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 900
                                    ? 4
                                    : constraints.maxWidth >= 600
                                    ? 3
                                    : 2;
                                return GridView.builder(
                                  key: const ValueKey(
                                    'progress-achievements-grid',
                                  ),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: achievements.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        mainAxisExtent: 164,
                                      ),
                                  itemBuilder: (context, index) =>
                                      _buildAchievementBadge(
                                        achievements[index],
                                      ),
                                );
                              },
                            ),
                        ],
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
                  'Knowledge Assignment',
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
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 148),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFFFFF8E1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? const Color(0xFFFFC44D) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AchievementMedal(achievement: achievement, size: 44),
          const SizedBox(height: 6),
          Text(
            achievement.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: unlocked ? const Color(0xFF6B4E00) : null,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            unlocked
                ? achievement.description
                : '${achievement.description} · ${achievement.current}/${achievement.target}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: unlocked ? const Color(0xFF8A6500) : Colors.grey.shade600,
              fontSize: 9.5,
              height: 1.2,
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

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 78,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(31),
          border: Border.all(color: const Color(0xFFD8E8F5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF357FBD).withValues(alpha: .2),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: items.map((item) {
            final index = item['index'] as int;
            final isSelected = _currentTabIndex == index;
            return Expanded(
              child: Semantics(
                selected: isSelected,
                button: true,
                label: item['label'] as String,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _selectTab(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF43A8F5), Color(0xFF1976E8)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF2488EC,
                                ).withValues(alpha: .3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (isSelected ? item['selectedIcon'] : item['icon'])
                              as IconData,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF65758E),
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF596981),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 31,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF56B7F5), Color(0xFF247FEA)],
          ),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF10213E),
          ),
        ),
      ),
      ExcludeSemantics(
        child: Row(
          children: List.generate(
            3,
            (index) => Container(
              width: 7,
              height: 19,
              margin: const EdgeInsets.only(left: 5),
              transform: Matrix4.skewX(-.35),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF328FE9,
                ).withValues(alpha: 1 - index * .18),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _StudentHomeBackgroundPainter extends CustomPainter {
  const _StudentHomeBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF1F9FF), Color(0xFFEAF5FF), Color(0xFFF7FBFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final topWave = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .16)
      ..cubicTo(
        size.width * .74,
        size.height * .08,
        size.width * .42,
        size.height * .21,
        0,
        size.height * .11,
      )
      ..close();
    canvas.drawPath(
      topWave,
      Paint()..color = const Color(0xFFB9E0FA).withValues(alpha: .22),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .94, size.height * .32),
        width: size.width * .5,
        height: size.width * .5,
      ),
      Paint()..color = const Color(0xFF76C4F5).withValues(alpha: .08),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .04, size.height * .78),
        width: size.width * .62,
        height: size.width * .42,
      ),
      Paint()..color = const Color(0xFF93D1F8).withValues(alpha: .1),
    );

    final lowerRibbon = Path()
      ..moveTo(0, size.height * .88)
      ..quadraticBezierTo(
        size.width * .28,
        size.height * .8,
        size.width * .52,
        size.height * .91,
      )
      ..quadraticBezierTo(
        size.width * .76,
        size.height,
        size.width,
        size.height * .89,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      lowerRibbon,
      Paint()..color = const Color(0xFF4AAAF0).withValues(alpha: .07),
    );
  }

  @override
  bool shouldRepaint(covariant _StudentHomeBackgroundPainter oldDelegate) =>
      false;
}

class AchievementUnlockCount extends StatelessWidget {
  const AchievementUnlockCount({
    super.key,
    required this.unlocked,
    required this.total,
  });

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) => Text(
    '$unlocked of $total unlocked',
    style: const TextStyle(
      color: Color(0xFF667085),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
  );
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
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(bgColor, Colors.white, .18)!,
                  Color.lerp(bgColor, Colors.white, .62)!,
                  Color.lerp(bgColor, color, .12)!,
                ],
                stops: const [0, .58, 1],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: .28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .14),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 190;
                return Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -18,
                      child: Transform.rotate(
                        angle: -.32,
                        child: Container(
                          width: 104,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: compact ? -36 : -24,
                      bottom: -28,
                      child: Transform.rotate(
                        angle: -.32,
                        child: Container(
                          width: compact ? 100 : 132,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 11 : 14),
                        child: Row(
                          children: [
                            Container(
                              width: compact ? 42 : 50,
                              height: compact ? 42 : 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.lerp(color, Colors.white, .18)!,
                                    color,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: .25),
                                    blurRadius: 9,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: compact ? 24 : 28,
                              ),
                            ),
                            SizedBox(width: compact ? 9 : 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF172033),
                                      fontSize: compact ? 13 : 15,
                                      height: 1.08,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: color.withValues(alpha: .92),
                                      fontSize: compact ? 10.5 : 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .72),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.withValues(alpha: .2),
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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
