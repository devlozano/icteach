import 'admin/principal_users_panel.dart';
import 'services/workspace_data.dart';
import 'widgets/staff_workspace_header.dart';

import 'widgets/performance_pie_chart.dart';
import 'widgets/summary_print_button.dart';
import 'services/personal_summary_service.dart';
import 'widgets/persistent_workspace.dart';
import 'widgets/principal_workspace_shell.dart';
import 'screens/staff_outcomes.dart';
import 'admin/school_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin/content_overview_page.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'admin/create_staff_page.dart';

import 'admin/evaluation_reports_page.dart';
import 'package:icteach/services/quiz_service.dart';
import 'admin_login.dart';
import 'services/workspace_preferences.dart';

// â”€â”€â”€ Color constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kNavColor = Color(0xFF0F172A);
const _kAccentBlue = Color(0xFF0891B2);
const _kCardBorder = Color(0xFFDCE4EC);
const _kSubtextColor = Color(0xFF64748B);
const _kBgColor = Color(0xFFF1F5F9);

void _openWebLogin(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    (route) => false,
  );
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String _currentSelectedLabel =
      (WorkspacePreferences.selection('admin_panel') ?? 'Dashboard')
          .replaceFirst('LRN Registry', 'Dashboard')
          .replaceFirst('LRN Registration', 'Dashboard');

  void _selectPanel(String label) {
    setState(() => _currentSelectedLabel = label);
    WorkspacePreferences.saveSelection('admin_panel', label);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No admin signed in.')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: WorkspaceData.profile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        final name = _adminName(profile, user);
        PrincipalWorkspaceNavigation.register(_selectPanel);
        PersistentWorkspace.register(
          context,
          PrincipalSidebar(
            currentSelection: _currentSelectedLabel,
            onSelected: (label) => PersistentWorkspace.returnHome(
              context,
              () => _selectPanel(label),
            ),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;
            final isCompact = constraints.maxWidth < 600;
            return Scaffold(
              backgroundColor: _kBgColor,
              drawer: isWide
                  ? null
                  : Drawer(
                      child: PrincipalSidebar(
                        currentSelection: _currentSelectedLabel,
                        onSelected: (label) {
                          _selectPanel(label);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
              body: SafeArea(
                child: Row(
                  children: [
                    if (isWide)
                      PrincipalSidebar(
                        currentSelection: _currentSelectedLabel,
                        onSelected: (label) {
                          _selectPanel(label);
                        },
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          StaffTopBar(
                            name: name,
                            showMenuButton: !isWide,
                            showNotifications: false,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                isCompact ? 12 : 28,
                                isCompact ? 14 : 24,
                                isCompact ? 12 : 28,
                                isCompact ? 24 : 36,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1400,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    StaffPageHeading(
                                      title: _currentSelectedLabel,
                                      subtitle: _getSubtitle(),
                                      icon: _sectionIcon(),
                                    ),
                                    const SizedBox(height: 20),
                                    if (const [
                                      'Dashboard',
                                      'Performance',
                                      'Content Overview',
                                      'Manage Classes',
                                    ].contains(_currentSelectedLabel))
                                      SummaryPrintButton(
                                        title:
                                            _currentSelectedLabel + ' summary',
                                        load: AdminSummaryService.load,
                                      ),
                                    _buildActivePanelContent(),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getSubtitle() {
    switch (_currentSelectedLabel) {
      case 'Dashboard':
        return 'Welcome back to ICTeach Admin';
      case 'Manage Users':
        return 'Create and manage teacher & trainer accounts';
      case 'Manage Classes':
        return 'View all classes across the platform';
      case 'Performance':
        return 'Track student quiz performance and leaderboards';
      case 'Reports':
        return 'Student counts and NC II pass monitoring';
      case 'Settings':
        return 'Manage your account and app preferences';
      default:
        return '';
    }
  }

  IconData _sectionIcon() {
    switch (_currentSelectedLabel) {
      case 'Manage Users':
        return Icons.manage_accounts_outlined;
      case 'Manage Classes':
        return Icons.school_outlined;
      case 'Performance':
        return Icons.analytics_outlined;
      case 'Reports':
        return Icons.description_outlined;
      case 'Settings':
        return Icons.settings_outlined;
      default:
        return Icons.space_dashboard_outlined;
    }
  }

  Widget _buildActivePanelContent() {
    switch (_currentSelectedLabel) {
      case 'Content Overview':
        return const ContentOverviewPage();
      case 'Dashboard':
        return const _DashboardContent();
      case 'Manage Users':
        return _ManageUsersContent();
      case 'Manage Classes':
        return const _ManageClassesContent();
      case 'Performance':
        return const _PerformanceContent();
      case 'Reports':
        return const StaffOutcomes(admin: true);
      case 'Feedback':
        return const Column(
          children: [
            StaffOutcomes(admin: true, feedback: true),
            SizedBox(height: 24),
            SizedBox(height: 640, child: EvaluationReportsPage()),
          ],
        );
      case 'School Profile':
        return const SchoolProfileEditor();
      case 'Settings':
        return const _SettingsContent();
      default:
        return const SizedBox.shrink();
    }
  }

  // â”€â”€ Manage Users â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _ManageUsersContent() => const PrincipalUsersPanel();
  String _adminName(Map<String, dynamic>? profile, User user) {
    final firstName = (profile?['firstName'] as String?)?.trim() ?? '';
    final middleName = (profile?['middleName'] as String?)?.trim() ?? '';
    final lastName = (profile?['lastName'] as String?)?.trim() ?? '';
    final extension = (profile?['extension'] as String?)?.trim() ?? '';
    final separatedName = [
      firstName,
      if (middleName.isNotEmpty)
        '${middleName.characters.first.toUpperCase()}.',
      lastName,
      if (extension.isNotEmpty) extension,
    ].where((part) => part.isNotEmpty).join(' ');

    if (separatedName.isNotEmpty) return separatedName;

    final savedName = profile?['name'] as String?;
    if (savedName != null && savedName.trim().isNotEmpty) {
      return savedName.trim();
    }

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    return 'Administrator';
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SIDE NAVIGATION
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth > 800;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SummaryRow(),
            SizedBox(height: desktop ? 12 : 16),
            if (desktop)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _RecentClassesGrid()),
                  SizedBox(width: 12),
                  SizedBox(width: 250, child: _QuickActionsCard()),
                ],
              )
            else
              const Column(
                children: [
                  _QuickActionsCard(),
                  SizedBox(height: 16),
                  _RecentClassesGrid(),
                ],
              ),
            SizedBox(height: desktop ? 12 : 16),
            const _RecentActivityCard(),
          ],
        );
      },
    );
  }
}

class _SummaryRow extends StatefulWidget {
  const _SummaryRow();

  @override
  State<_SummaryRow> createState() => _SummaryRowState();
}

class _SummaryRowState extends State<_SummaryRow> {
  int totalUsers = 0;
  int teachers = 0;
  int trainers = 0;
  int students = 0;
  int totalClasses = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        db.collection('users').count().get(),
        db
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .count()
            .get(),
        db
            .collection('users')
            .where('role', isEqualTo: 'trainer')
            .count()
            .get(),
        db
            .collection('users')
            .where('role', isEqualTo: 'student')
            .count()
            .get(),
        db.collection('classes').count().get(),
      ]);

      if (mounted) {
        setState(() {
          totalUsers = results[0].count ?? 0;
          teachers = results[1].count ?? 0;
          trainers = results[2].count ?? 0;
          students = results[3].count ?? 0;
          totalClasses = results[4].count ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _LoadingShimmer(height: 124);
    }

    final cards = [
      _StatCardData(
        title: 'Total Users',
        value: totalUsers.toString(),
        subtitle: 'All registered accounts',
        icon: Icons.groups_rounded,
        color: _kAccentBlue,
      ),
      _StatCardData(
        title: 'Teachers',
        value: teachers.toString(),
        subtitle: 'Active teachers',
        icon: Icons.school_rounded,
        color: const Color(0xFF2F80ED),
      ),
      _StatCardData(
        title: 'Trainers',
        value: trainers.toString(),
        subtitle: 'Industry trainers',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF9C4FA1),
      ),
      _StatCardData(
        title: 'Students',
        value: students.toString(),
        subtitle: 'Currently enrolled',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF28C76F),
      ),
      _StatCardData(
        title: 'Classes',
        value: totalClasses.toString(),
        subtitle: 'Active classes',
        icon: Icons.class_rounded,
        color: const Color(0xFFE94560),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 5
            : constraints.maxWidth >= 680
            ? 3
            : constraints.maxWidth >= 440
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 124,
          ),
          itemBuilder: (_, index) => _SmallStat(data: cards[index]),
        );
      },
    );
  }
}

class _StatCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: data.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: const TextStyle(fontSize: 11, color: _kSubtextColor),
          ),
        ],
      ),
    );
  }
}

class _RecentClassesGrid extends StatelessWidget {
  const _RecentClassesGrid();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F80ED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.class_rounded,
                  color: Color(0xFF2F80ED),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recent Classes',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('classes')
                .orderBy('createdAt', descending: true)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingShimmer(height: 100);
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.class_outlined,
                  message: 'No classes found',
                  subtitle: 'Classes will appear once teachers create them',
                );
              }

              final docs = snapshot.data!.docs;
              final colors = [
                const Color(0xFF2F80ED),
                const Color(0xFF28C76F),
                const Color(0xFF9C4FA1),
                const Color(0xFFE94560),
              ];

              return LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 10.0;
                  final columnCount = constraints.maxWidth >= 960
                      ? 4
                      : constraints.maxWidth >= 680
                      ? 3
                      : constraints.maxWidth >= 440
                      ? 2
                      : 1;
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columnCount - 1)) /
                      columnCount;

                  return Wrap(
                    runSpacing: spacing,
                    spacing: spacing,
                    children: List.generate(docs.length, (index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = data['name'] as String? ?? 'Untitled Class';
                      final sectionValue =
                          (data['sectionCode'] as String?)?.trim() ?? '';
                      final section = sectionValue.isEmpty
                          ? 'Section not assigned'
                          : sectionValue;
                      final students =
                          (data['enrolledStudentIds'] as List?)?.length ?? 0;
                      final teacherValue =
                          (data['teacherName'] as String?)?.trim() ?? '';
                      final teacherName = teacherValue.isEmpty
                          ? 'Teacher not assigned'
                          : teacherValue;
                      final color = colors[index % colors.length];

                      return _ClassCard(
                        width: cardWidth,
                        title: name,
                        section: section,
                        teacherName: teacherName,
                        studentsCount: students,
                        color: color,
                      );
                    }),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.width,
    required this.title,
    required this.section,
    required this.teacherName,
    required this.studentsCount,
    required this.color,
  });

  final double width;
  final String title;
  final String section;
  final String teacherName;
  final int studentsCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.09),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.14),
                    color.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.class_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF20242C),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            section,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TEACHER',
                              style: TextStyle(
                                color: Color(0xFF8A94A3),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              teacherName,
                              style: const TextStyle(
                                color: Color(0xFF303640),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFEEF0F3))),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          '$studentsCount ${studentsCount == 1 ? 'student' : 'students'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Recent Activity â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE76C31).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFFE76C31),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recent Signups',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingShimmer(height: 120);
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.history,
                  message: 'No recent activity',
                );
              }
              final docs = snapshot.data!.docs;
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = data['role'] as String? ?? 'user';
                  final roleColors = {
                    'teacher': const Color(0xFF2F80ED),
                    'trainer': Colors.purple,
                    'student': const Color(0xFF28C76F),
                    'admin': const Color(0xFFE94560),
                  };
                  final color = roleColors[role] ?? const Color(0xFF666666);
                  final name =
                      data['firstName'] != null && data['lastName'] != null
                      ? '${data['firstName']} ${data['lastName']}'
                      : data['name']?.toString() ?? 'Unknown User';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final dateStr = createdAt != null
                      ? _formatDate(createdAt.toDate())
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(
                            role == 'teacher'
                                ? Icons.school
                                : role == 'trainer'
                                ? Icons.verified_user
                                : Icons.person,
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Color(0xFFBDBDBD),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Quick Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        label: 'Create Teacher',
        icon: Icons.person_add,
        color: const Color(0xFF2F80ED),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateStaffPage(selectedRole: 'teacher'),
          ),
        ),
      ),
      _ActionItem(
        label: 'Create Trainer',
        icon: Icons.person_add_alt_1,
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateStaffPage(selectedRole: 'trainer'),
          ),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF168D92).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFF168D92),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...actions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: a.color.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: a.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(a.icon, color: a.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            a.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionItem({
    required this.label,
    required this.icon,
    this.color = const Color(0xFF168D92),
    this.onTap,
  });
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MANAGE CLASSES CONTENT (NEW)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ManageClassesContent extends StatefulWidget {
  const _ManageClassesContent();

  @override
  State<_ManageClassesContent> createState() => _ManageClassesContentState();
}

class _ManageClassesContentState extends State<_ManageClassesContent> {
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'archived'

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: constraints.maxWidth < 520
                      ? 'Search classes...'
                      : 'Search classes by name, section, or teacher...',
                  prefixIcon: const Icon(Icons.search, color: _kSubtextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  filled: true,
                  fillColor: _kBgColor,
                ),
              );
              final filter = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: _kBgColor,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    isExpanded: constraints.maxWidth < 520,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'archived',
                        child: Text('Archived'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: filter),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  filter,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Classes list
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingShimmer(height: 300);
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}');
            }

            final allClasses = snapshot.data?.docs ?? [];

            // Apply filters
            final filtered = allClasses.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] as String? ?? '').toLowerCase();
              final section = (data['sectionCode'] as String? ?? '')
                  .toLowerCase();
              final teacher = (data['teacherName'] as String? ?? '')
                  .toLowerCase();
              final status = data['status'] as String? ?? 'active';

              final matchesSearch =
                  _searchQuery.isEmpty ||
                  name.contains(_searchQuery) ||
                  section.contains(_searchQuery) ||
                  teacher.contains(_searchQuery);

              final matchesStatus =
                  _statusFilter == 'all' || status == _statusFilter;

              return matchesSearch && matchesStatus;
            }).toList();

            if (filtered.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kCardBorder),
                ),
                child: _EmptyState(
                  icon: Icons.class_outlined,
                  message: allClasses.isEmpty
                      ? 'No classes created yet'
                      : 'No classes match your filters',
                  subtitle: allClasses.isEmpty
                      ? 'Teachers can create classes from their dashboard'
                      : 'Try adjusting your search or filter',
                ),
              );
            }

            // Summary row
            final activeCount = allClasses
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['status'] !=
                      'archived',
                )
                .length;
            final totalStudents = allClasses.fold<int>(0, (sum, doc) {
              final data = doc.data() as Map<String, dynamic>;
              return sum + ((data['enrolledStudentIds'] as List?)?.length ?? 0);
            });

            return Column(
              children: [
                // Stats bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kNavColor.withOpacity(0.05),
                        _kAccentBlue.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kAccentBlue.withOpacity(0.15)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MiniStat(
                          label: 'Total',
                          value: '${allClasses.length}',
                          color: _kNavColor,
                        ),
                        const SizedBox(width: 24),
                        _MiniStat(
                          label: 'Active',
                          value: '$activeCount',
                          color: const Color(0xFF28C76F),
                        ),
                        const SizedBox(width: 24),
                        _MiniStat(
                          label: 'Students',
                          value: '$totalStudents',
                          color: _kAccentBlue,
                        ),
                        const SizedBox(width: 24),
                        _MiniStat(
                          label: 'Showing',
                          value: '${filtered.length}',
                          color: const Color(0xFFE94560),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Class rows remain readable on narrow admin windows.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = constraints.maxWidth < 760
                        ? 760.0
                        : constraints.maxWidth;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kCardBorder),
                          ),
                          child: Column(
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _kBgColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Class',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _kSubtextColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Teacher',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _kSubtextColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Students',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _kSubtextColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _kSubtextColor,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        'Actions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _kSubtextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final doc = filtered[index];
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final name =
                                      data['name'] as String? ?? 'Untitled';
                                  final section =
                                      data['sectionCode'] as String? ?? '';
                                  final teacherName =
                                      data['teacherName'] as String? ??
                                      'Unknown';
                                  final studentCount =
                                      (data['enrolledStudentIds'] as List?)
                                          ?.length ??
                                      0;
                                  final status =
                                      data['status'] as String? ?? 'active';
                                  final classCode =
                                      data['classCode'] as String? ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Text(
                                                    section,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _kSubtextColor,
                                                    ),
                                                  ),
                                                  if (classCode.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    InkWell(
                                                      onTap: () {
                                                        Clipboard.setData(
                                                          ClipboardData(
                                                            text: classCode,
                                                          ),
                                                        );
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Code "$classCode" copied!',
                                                            ),
                                                            duration:
                                                                const Duration(
                                                                  seconds: 2,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: _kAccentBlue
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              classCode,
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    _kAccentBlue,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            const Icon(
                                                              Icons.copy,
                                                              size: 10,
                                                              color:
                                                                  _kAccentBlue,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            teacherName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.people_alt_outlined,
                                                size: 14,
                                                color: _kSubtextColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$studentCount',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: _StatusBadge(
                                            isActive: status == 'active',
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: PopupMenuButton<String>(
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: _kSubtextColor,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            itemBuilder: (ctx) => [
                                              PopupMenuItem(
                                                value: status == 'active'
                                                    ? 'archive'
                                                    : 'activate',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      status == 'active'
                                                          ? Icons.archive
                                                          : Icons.unarchive,
                                                      size: 18,
                                                      color: Colors.orange,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      status == 'active'
                                                          ? 'Archive'
                                                          : 'Activate',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete_outline,
                                                      size: 18,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('Delete'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onSelected: (value) =>
                                                _handleClassAction(
                                                  context,
                                                  doc.id,
                                                  name,
                                                  value,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleClassAction(
    BuildContext context,
    String classId,
    String className,
    String action,
  ) async {
    if (action == 'archive' || action == 'activate') {
      final newStatus = action == 'archive' ? 'archived' : 'active';
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Class "$className" ${action == 'archive' ? 'archived' : 'activated'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Class'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "$className"? This action cannot be undone and will remove all associated data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Class "$className" deleted'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _kSubtextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// PERFORMANCE CONTENT
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _PerformanceContent extends StatefulWidget {
  const _PerformanceContent();

  @override
  State<_PerformanceContent> createState() => _PerformanceContentState();
}

class _PerformanceContentState extends State<_PerformanceContent> {
  final QuizService _quizService = QuizService();
  late final _leaderboard = _quizService.getGlobalLeaderboard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _leaderboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer(height: 300);
        }

        if (snapshot.hasError) {
          return _ErrorCard(message: '${snapshot.error}');
        }

        final leaderboard = snapshot.data ?? [];

        if (leaderboard.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kCardBorder),
            ),
            child: const _EmptyState(
              icon: Icons.analytics_outlined,
              message: 'No Performance Data',
              subtitle: 'No quiz results have been recorded yet.',
            ),
          );
        }

        return PerformancePieChart(entries: leaderboard);
      },
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// REPORTS CONTENT (NEW)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ReportsContent extends StatefulWidget {
  const _ReportsContent();

  @override
  State<_ReportsContent> createState() => _ReportsContentState();
}

class _ReportsContentState extends State<_ReportsContent> {
  bool _isLoading = true;
  int _totalQuizzes = 0;
  int _totalAssignments = 0;
  int _totalModules = 0;
  int _totalQuizSubmissions = 0;
  int _totalAssignmentSubmissions = 0;
  List<Map<String, dynamic>> _classBreakdown = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    try {
      final db = FirebaseFirestore.instance;

      // Get all classes
      final classesSnapshot = await db.collection('classes').get();
      final classes = classesSnapshot.docs;

      int totalQuizzes = 0;
      int totalAssignments = 0;
      int totalModules = 0;
      List<Map<String, dynamic>> breakdown = [];

      for (final classDoc in classes) {
        final classData = classDoc.data();
        final classId = classDoc.id;
        final className = classData['name'] as String? ?? 'Untitled';
        final teacherName = classData['teacherName'] as String? ?? 'Unknown';
        final studentCount =
            (classData['enrolledStudentIds'] as List?)?.length ?? 0;

        // Count subcollections
        final quizCount = await db
            .collection('classes')
            .doc(classId)
            .collection('quizzes')
            .count()
            .get();
        final assignmentCount = await db
            .collection('classes')
            .doc(classId)
            .collection('assignments')
            .count()
            .get();
        final moduleCount = await db
            .collection('classes')
            .doc(classId)
            .collection('modules')
            .count()
            .get();

        final qc = quizCount.count ?? 0;
        final ac = assignmentCount.count ?? 0;
        final mc = moduleCount.count ?? 0;

        totalQuizzes += qc;
        totalAssignments += ac;
        totalModules += mc;

        breakdown.add({
          'className': className,
          'teacherName': teacherName,
          'studentCount': studentCount,
          'quizCount': qc,
          'assignmentCount': ac,
          'moduleCount': mc,
        });
      }

      // Count global submissions
      final quizSubmissions = await db.collection('quiz_results').count().get();
      final assignmentSubmissions = await db
          .collection('submissions')
          .count()
          .get();

      // Sort breakdown by student count
      breakdown.sort(
        (a, b) =>
            (b['studentCount'] as int).compareTo(a['studentCount'] as int),
      );

      if (mounted) {
        setState(() {
          _totalQuizzes = totalQuizzes;
          _totalAssignments = totalAssignments;
          _totalModules = totalModules;
          _totalQuizSubmissions = quizSubmissions.count ?? 0;
          _totalAssignmentSubmissions = assignmentSubmissions.count ?? 0;
          _classBreakdown = breakdown;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _LoadingShimmer(height: 400);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Platform Overview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F80ED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Color(0xFF2F80ED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Platform Content Overview',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadReportData();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ReportStatCard(
                    title: 'Quizzes',
                    value: '$_totalQuizzes',
                    icon: Icons.quiz_rounded,
                    color: const Color(0xFF2F80ED),
                  ),
                  _ReportStatCard(
                    title: 'Assignments',
                    value: '$_totalAssignments',
                    icon: Icons.assignment_rounded,
                    color: const Color(0xFFE76C31),
                  ),
                  _ReportStatCard(
                    title: 'Modules',
                    value: '$_totalModules',
                    icon: Icons.library_books_rounded,
                    color: const Color(0xFF9C4FA1),
                  ),
                  _ReportStatCard(
                    title: 'Quiz Submissions',
                    value: '$_totalQuizSubmissions',
                    icon: Icons.fact_check_rounded,
                    color: const Color(0xFF28C76F),
                  ),
                  _ReportStatCard(
                    title: 'Assignment Submissions',
                    value: '$_totalAssignmentSubmissions',
                    icon: Icons.upload_file_rounded,
                    color: const Color(0xFFE94560),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Class Breakdown Table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF28C76F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.table_chart_rounded,
                        color: Color(0xFF28C76F),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Class-Level Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_classBreakdown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: _EmptyState(
                    icon: Icons.class_outlined,
                    message: 'No classes to report on',
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(_kBgColor),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Class',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Teacher',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Students',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text(
                          'Quizzes',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text(
                          'Assignments',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text(
                          'Modules',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        numeric: true,
                      ),
                    ],
                    rows: _classBreakdown.map((data) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              data['className'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(Text(data['teacherName'] as String)),
                          DataCell(Text('${data['studentCount']}')),
                          DataCell(
                            _CountBadge(
                              count: data['quizCount'] as int,
                              color: const Color(0xFF2F80ED),
                            ),
                          ),
                          DataCell(
                            _CountBadge(
                              count: data['assignmentCount'] as int,
                              color: const Color(0xFFE76C31),
                            ),
                          ),
                          DataCell(
                            _CountBadge(
                              count: data['moduleCount'] as int,
                              color: const Color(0xFF9C4FA1),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  const _ReportStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.06), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: count > 0 ? color : Colors.grey,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SETTINGS CONTENT (NEW)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _SettingsContent extends StatefulWidget {
  const _SettingsContent();

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoadingAcademicYear = true;
  bool _isSavingAcademicYear = false;
  late String _selectedAcademicYear;

  String _automaticAcademicYear() {
    final now = DateTime.now();
    final start = now.month >= 6 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }

  @override
  void initState() {
    super.initState();
    _selectedAcademicYear = _automaticAcademicYear();
    _applyAcademicYear(_selectedAcademicYear);
    _loadAcademicYear();
  }

  void _applyAcademicYear(String schoolYear) {
    final parts = schoolYear.split('-');
    final start = parts.isNotEmpty ? int.tryParse(parts.first.trim()) : null;
    final resolvedStart = start ?? DateTime.now().year;
    _startYearController.text = resolvedStart.toString();
    _endYearController.text = (resolvedStart + 1).toString();
    _selectedAcademicYear = '$resolvedStart-${resolvedStart + 1}';
  }

  void _updateEndYear(String value) {
    final start = int.tryParse(value);
    final end = start == null ? '' : (start + 1).toString();
    _endYearController.text = end;
    if (value.length == 4 && start != null) {
      _selectedAcademicYear = '$start-${start + 1}';
    }
    setState(() {});
  }

  String? _validatedAcademicYear() {
    final start = int.tryParse(_startYearController.text.trim());
    if (start == null || _startYearController.text.trim().length != 4) {
      _showSnack('Enter a valid four-digit start year.', Colors.red);
      return null;
    }
    if (start < 1900 || start >= 9999) {
      _showSnack('Start year must be between 1900 and 9998.', Colors.red);
      return null;
    }
    final schoolYear = '$start-${start + 1}';
    _endYearController.text = (start + 1).toString();
    _selectedAcademicYear = schoolYear;
    return schoolYear;
  }

  Future<void> _loadAcademicYear() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('academic_year')
          .get();
      final saved = snapshot.data()?['activeSchoolYear']?.toString();
      if (mounted && saved != null && saved.isNotEmpty) {
        setState(() => _applyAcademicYear(saved));
      }
    } finally {
      if (mounted) setState(() => _isLoadingAcademicYear = false);
    }
  }

  Future<void> _saveAcademicYear({required bool archivePrevious}) async {
    final academicYear = _validatedAcademicYear();
    if (academicYear == null) return;
    setState(() => _isSavingAcademicYear = true);
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('system_settings').doc('academic_year').set({
        'activeSchoolYear': academicYear,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      var archivedCount = 0;
      if (archivePrevious) {
        final classes = await db.collection('classes').get();
        WriteBatch batch = db.batch();
        var pendingWrites = 0;
        for (final classDoc in classes.docs) {
          final data = classDoc.data();
          final year = data['schoolYear']?.toString();
          final status = data['status']?.toString();
          if (year != academicYear && status != 'archived') {
            batch.update(classDoc.reference, {
              'status': 'archived',
              'archivedAt': FieldValue.serverTimestamp(),
              'archiveReason': 'Academic year changed to $academicYear',
            });
            archivedCount++;
            pendingWrites++;
            if (pendingWrites == 450) {
              await batch.commit();
              batch = db.batch();
              pendingWrites = 0;
            }
          }
        }
        if (pendingWrites > 0) await batch.commit();
      }

      _showSnack(
        archivePrevious
            ? 'Academic year saved. $archivedCount previous class(es) archived.'
            : 'Active academic year saved.',
        Colors.green,
      );
    } catch (e) {
      _showSnack('Unable to update academic year: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSavingAcademicYear = false);
    }
  }

  Future<void> _confirmAcademicYearRollover() async {
    final academicYear = _validatedAcademicYear();
    if (academicYear == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start academic year rollover?'),
        content: Text(
          'This sets $academicYear as active and archives every class '
          'from another school year. Archived classes remain available in the '
          'Classes archive and their records are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save and archive'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _saveAcademicYear(archivePrevious: true);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all password fields', Colors.red);
      return;
    }
    if (newPass.length < 6) {
      _showSnack('New password must be at least 6 characters', Colors.red);
      return;
    }
    if (newPass != confirm) {
      _showSnack('New passwords do not match', Colors.red);
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception('No user');

      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnack('Password changed successfully!', Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Authentication error', Colors.red);
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Admin Profile
        const SchoolProfileEditor(),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: _kAccentBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Academic Year and Archiving',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'New classes use the active academic year. A rollover archives '
                'older classes without deleting lessons, submissions, or results.',
                style: TextStyle(color: _kSubtextColor, height: 1.45),
              ),
              const SizedBox(height: 18),
              if (_isLoadingAcademicYear)
                const LinearProgressIndicator()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stackFields = constraints.maxWidth < 420;

                          final startYearField = TextFormField(
                            controller: _startYearController,
                            enabled: !_isSavingAcademicYear,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'START YEAR',
                              hintText: '2026',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: _updateEndYear,
                          );

                          final endYearField = TextFormField(
                            controller: _endYearController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'END YEAR',
                              filled: true,
                              fillColor: Color(0xFFF1F5F9),
                              suffixIcon: Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          );

                          final connector = Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _kAccentBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              stackFields
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_forward_rounded,
                              color: _kAccentBlue,
                              size: 18,
                            ),
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (stackFields) ...[
                                startYearField,
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Center(child: connector),
                                ),
                                endYearField,
                              ] else
                                Row(
                                  children: [
                                    Expanded(child: startYearField),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: connector,
                                    ),
                                    Expanded(child: endYearField),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 15,
                                    color: _kAccentBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _endYearController.text.isEmpty
                                          ? 'Enter a start year to calculate the end year.'
                                          : 'School year: ${_startYearController.text}-${_endYearController.text}. The end year is filled automatically.',
                                      style: const TextStyle(
                                        color: _kSubtextColor,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSavingAcademicYear
                              ? null
                              : () => _saveAcademicYear(archivePrevious: false),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save active year'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(170, 46),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSavingAcademicYear
                              ? null
                              : _confirmAcademicYearRollover,
                          icon: const Icon(Icons.archive_rounded, size: 18),
                          label: const Text('Save and archive previous years'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(250, 46),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Change Password
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _PasswordField(
                controller: _currentPasswordController,
                label: 'Current Password',
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _newPasswordController,
                label: 'New Password',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isChangingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isChangingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Sign Out & App Info
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingRow(
                icon: Icons.info_outline,
                label: 'App Version',
                value: '1.0.0',
              ),
              const Divider(height: 24),
              _SettingRow(
                icon: Icons.school,
                label: 'Platform',
                value: 'ICTeach LMS',
              ),
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      PersistentWorkspace.clear();
                      if (context.mounted) {
                        _openWebLogin(context);
                      }
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: _kSubtextColor,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kSubtextColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _kSubtextColor, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SHARED WIDGETS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _kAccentBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading...',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.subtitle});

  final IconData icon;
  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF666666),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Error: $message',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
