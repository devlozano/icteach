import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin/content_overview_page.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'admin/create_staff_page.dart';
import 'admin/manage_lrn_page.dart';
import 'admin/manage_trainers_page.dart';
import 'admin/evaluation_reports_page.dart';
import 'package:icteach/screens/notification_page.dart';
import 'package:icteach/widgets/notification_badge.dart';
import 'package:icteach/services/quiz_service.dart';
import 'admin_login.dart';
import 'services/workspace_preferences.dart';

// ─── Color constants ──────────────────────────────────────────────────────────
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
      WorkspacePreferences.selection('admin_panel') ?? 'Dashboard';
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
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        final name = _adminName(profile, user);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;
            final isCompact = constraints.maxWidth < 600;
            return Scaffold(
              backgroundColor: _kBgColor,
              drawer: isWide
                  ? null
                  : Drawer(
                      child: _SideNav(
                        currentSelection: _currentSelectedLabel,
                        adminName: name,
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
                      _SideNav(
                        currentSelection: _currentSelectedLabel,
                        adminName: name,
                        onSelected: (label) {
                          _selectPanel(label);
                        },
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(name: name, showMenuButton: !isWide),
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
                                    _AdminPageHeading(
                                      title: _currentSelectedLabel,
                                      subtitle: _getSubtitle(),
                                      icon: _sectionIcon(),
                                    ),
                                    const SizedBox(height: 20),
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
        return 'Platform-wide analytics and content statistics';
      case 'LRN Registry':
        return 'Manage LRN registration and master records';
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
      case 'LRN Registry':
        return Icons.badge_outlined;
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
        return const _ReportsContent();
      case 'LRN Registry':
        return const _LRNRegistryContent();
      case 'Settings':
        return const _SettingsContent();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Manage Users ────────────────────────────────────────────────────────────
  Widget _ManageUsersContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Teacher Section
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F80ED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Color(0xFF2F80ED),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Teachers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateStaffPage(selectedRole: 'teacher'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Teacher'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'teacher')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingShimmer(height: 150);
                  }
                  if (snapshot.hasError) {
                    return _ErrorCard(message: '${snapshot.error}');
                  }
                  final teachers = snapshot.data?.docs ?? [];
                  if (teachers.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.school_outlined,
                      message: 'No teachers found',
                      subtitle: 'Add teachers to start managing classes',
                    );
                  }

                  return Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: teachers.length > 5 ? 5 : teachers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final doc = teachers[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};
                          final name = data['name']?.toString() ?? 'Unknown';
                          final email = data['email']?.toString() ?? '';
                          final isActive = data['isActive'] ?? true;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(
                                0xFF2F80ED,
                              ).withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                style: const TextStyle(
                                  color: Color(0xFF2F80ED),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _StatusBadge(isActive: isActive),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right,
                                  color: _kSubtextColor,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (teachers.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: Text('View all ${teachers.length} teachers'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Trainer Section
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.purple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Trainers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateStaffPage(selectedRole: 'trainer'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Trainer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageTrainersPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user, color: Colors.purple),
                  label: const Text('View & Manage All Trainers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: Colors.purple),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage trainer accounts, assign to classes, and track their performance.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // LRN Master List
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2B4A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.numbers,
                      color: Color(0xFF0B2B4A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'LRN Registration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageLRNPage()),
                    );
                  },
                  icon: const Icon(Icons.numbers, color: Color(0xFF0B2B4A)),
                  label: const Text('Open LRN Master List'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0B2B4A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: Color(0xFF0B2B4A)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload LRN CSVs, validate registrations, and manage the student master list.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Students overview
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28C76F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Color(0xFF28C76F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Students',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'student')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingShimmer(height: 80);
                  }
                  final students = snapshot.data?.docs ?? [];
                  if (students.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.people_outline,
                      message: 'No students registered',
                      subtitle: 'Students will appear once they register',
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF28C76F).withOpacity(0.05),
                              const Color(0xFF28C76F).withOpacity(0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF28C76F).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_alt,
                              color: Color(0xFF28C76F),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${students.length}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF28C76F),
                                  ),
                                ),
                                Text(
                                  'Total registered students',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: students.length > 5 ? 5 : students.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data =
                              students[index].data() as Map<String, dynamic>? ??
                              {};
                          final name =
                              data['name']?.toString() ?? 'Unknown Student';
                          final email = data['email']?.toString() ?? '';
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(
                                0xFF28C76F,
                              ).withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  color: Color(0xFF28C76F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                      if (students.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '+ ${students.length - 5} more students',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

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

// ═══════════════════════════════════════════════════════════════════════════════
// SIDE NAVIGATION
// ═══════════════════════════════════════════════════════════════════════════════
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.currentSelection,
    required this.onSelected,
    required this.adminName,
  });

  final String currentSelection;
  final ValueChanged<String> onSelected;
  final String adminName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF162A3D)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Image.asset('assets/ict_logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              const Text(
                'ICTeach',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kAccentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Admin Panel',
                style: TextStyle(
                  color: _kAccentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NavTile(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: currentSelection == 'Dashboard',
                  onTap: () => onSelected('Dashboard'),
                ),
                _NavTile(
                  icon: Icons.people_alt_rounded,
                  label: 'Manage Users',
                  selected: currentSelection == 'Manage Users',
                  onTap: () => onSelected('Manage Users'),
                ),
                _NavTile(
                  icon: Icons.class_rounded,
                  label: 'Manage Classes',
                  selected: currentSelection == 'Manage Classes',
                  onTap: () => onSelected('Manage Classes'),
                ),
                _NavTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Content Overview',
                  selected: currentSelection == 'Content Overview',
                  onTap: () => onSelected('Content Overview'),
                ),
                _NavTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Performance',
                  selected: currentSelection == 'Performance',
                  onTap: () => onSelected('Performance'),
                ),
                _NavTile(
                  icon: Icons.assessment_rounded,
                  label: 'Reports',
                  selected: currentSelection == 'Reports',
                  onTap: () => onSelected('Reports'),
                ),
                _NavTile(
                  icon: Icons.numbers_rounded,
                  label: 'LRN Registry',
                  selected: currentSelection == 'LRN Registry',
                  onTap: () => onSelected('LRN Registry'),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 20),
          _NavTile(
            icon: Icons.settings_rounded,
            label: 'Settings',
            selected: currentSelection == 'Settings',
            onTap: () => onSelected('Settings'),
          ),
          const SizedBox(height: 12),
          // Admin info & logout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _kAccentBlue,
                  child: Text(
                    adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Administrator',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
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
                      if (context.mounted) {
                        _openWebLogin(context);
                      }
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = selected ? _kAccentBlue : Colors.white70;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white.withOpacity(0.04),
          splashColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Icon(icon, color: activeColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _kAccentBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOP BAR (FIXED: removed duplicate notification icon, fixed hardcoded avatar)
// ═══════════════════════════════════════════════════════════════════════════════
class _AdminPageHeading extends StatelessWidget {
  const _AdminPageHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFEFFBFD)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _kAccentBlue.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _kAccentBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _kSubtextColor, fontSize: 13),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 600)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F7F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text(
                    'SYSTEM ONLINE',
                    style: TextStyle(
                      color: Color(0xFF0F766E),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.showMenuButton});
  final String name;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final width = MediaQuery.sizeOf(context).width;
    final showWorkspaceTitle = width >= 430;
    final showProfileDetails = width >= 650;

    return Container(
      height: 52,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: width < 400 ? 6 : 18),
      foregroundDecoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kCardBorder)),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: _kNavColor),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          if (showWorkspaceTitle)
            Expanded(
              child: Text(
                'Administration Workspace',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            )
          else
            const Spacer(),
          // Notification bell
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
                color: Color(0xFF666666),
                size: 26,
              ),
              tooltip: 'Notifications',
            ),
          ),
          const SizedBox(width: 8),
          // Admin profile chip
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: showProfileDetails ? 14 : 7,
              vertical: 7,
            ),
            child: Row(
              children: [
                if (showProfileDetails) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _kAccentBlue,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD CONTENT
// ═══════════════════════════════════════════════════════════════════════════════
class _LRNRegistryContent extends StatelessWidget {
  const _LRNRegistryContent();

  @override
  Widget build(BuildContext context) {
    return const ManageLRNPage(useStandaloneScaffold: false);
  }
}

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

// ── Summary Row ───────────────────────────────────────────────────────────────
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

// ── Recent Classes ────────────────────────────────────────────────────────────
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
                  color: const Color(0xFF2F80ED).withOpacity(0.1),
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

              return Wrap(
                runSpacing: 12,
                spacing: 12,
                children: List.generate(docs.length, (index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? 'Untitled Class';
                  final section =
                      data['sectionCode'] as String? ?? 'No section';
                  final students =
                      (data['enrolledStudentIds'] as List?)?.length ?? 0;
                  final teacherName =
                      data['teacherName'] as String? ?? 'Unknown';
                  final color = colors[index % colors.length];

                  return _ClassCard(
                    title: name,
                    subtitle: '$section • $teacherName',
                    studentsCount: students,
                    color: color,
                  );
                }),
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
    required this.title,
    required this.subtitle,
    required this.studentsCount,
    required this.color,
  });

  final String title;
  final String subtitle;
  final int studentsCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '$studentsCount students',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Activity ───────────────────────────────────────────────────────────
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

// ── Quick Actions ─────────────────────────────────────────────────────────────
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

// ═══════════════════════════════════════════════════════════════════════════════
// MANAGE CLASSES CONTENT (NEW)
// ═══════════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE CONTENT
// ═══════════════════════════════════════════════════════════════════════════════
class _PerformanceContent extends StatefulWidget {
  const _PerformanceContent();

  @override
  State<_PerformanceContent> createState() => _PerformanceContentState();
}

class _PerformanceContentState extends State<_PerformanceContent> {
  final QuizService _quizService = QuizService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _quizService.getGlobalLeaderboard(),
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

        return Container(
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
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Global Leaderboard',
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${leaderboard.length} students',
                        style: const TextStyle(
                          color: _kAccentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                itemCount: leaderboard.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = leaderboard[index];
                  final isTop3 = index < 3;
                  final medalColors = [
                    Colors.amber.shade600,
                    Colors.grey.shade500,
                    Colors.brown.shade400,
                  ];
                  final color = isTop3 ? medalColors[index] : _kNavColor;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: isTop3
                            ? LinearGradient(
                                colors: [
                                  color.withOpacity(0.2),
                                  color.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isTop3 ? null : color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: isTop3
                            ? Icon(Icons.emoji_events, color: color, size: 22)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      data['studentName'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${data['quizCount']} quizzes taken'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${data['percentage']}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPORTS CONTENT (NEW)
// ═══════════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════════
// SETTINGS CONTENT (NEW)
// ═══════════════════════════════════════════════════════════════════════════════
class _SettingsContent extends StatefulWidget {
  const _SettingsContent();

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoadingAcademicYear = true;
  bool _isSavingAcademicYear = false;
  late String _selectedAcademicYear;

  List<String> get _academicYearOptions {
    final currentYear = DateTime.now().year;
    return List.generate(7, (index) {
      final start = currentYear - 3 + index;
      return '$start-${start + 1}';
    });
  }

  String _automaticAcademicYear() {
    final now = DateTime.now();
    final start = now.month >= 6 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }

  @override
  void initState() {
    super.initState();
    _selectedAcademicYear = _automaticAcademicYear();
    _loadAcademicYear();
  }

  Future<void> _loadAcademicYear() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('academic_year')
          .get();
      final saved = snapshot.data()?['activeSchoolYear']?.toString();
      if (mounted && saved != null && saved.isNotEmpty) {
        setState(() => _selectedAcademicYear = saved);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAcademicYear = false);
    }
  }

  Future<void> _saveAcademicYear({required bool archivePrevious}) async {
    setState(() => _isSavingAcademicYear = true);
    try {
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      await db.collection('system_settings').doc('academic_year').set({
        'activeSchoolYear': _selectedAcademicYear,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
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
          if (year != _selectedAcademicYear && status != 'archived') {
            batch.update(classDoc.reference, {
              'status': 'archived',
              'archivedAt': FieldValue.serverTimestamp(),
              'archiveReason':
                  'Academic year changed to $_selectedAcademicYear',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start academic year rollover?'),
        content: Text(
          'This sets $_selectedAcademicYear as active and archives every class '
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
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Admin Profile
        StreamBuilder<DocumentSnapshot>(
          stream: user != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final name = data?['name']?.toString() ?? 'Administrator';
            final email = data?['email']?.toString() ?? user?.email ?? '';
            final role = data?['role']?.toString() ?? 'admin';
            final createdAt = data?['createdAt'] as Timestamp?;

            return Container(
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
                          color: _kAccentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: _kAccentBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Admin Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: _kAccentBlue,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: _kSubtextColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _kSubtextColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kAccentBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: const TextStyle(
                                      color: _kAccentBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (createdAt != null) ...[
                                  Text(
                                    'Joined ${DateFormat('MMM d, y').format(createdAt.toDate())}',
                                    style: const TextStyle(
                                      color: _kSubtextColor,
                                      fontSize: 12,
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
                ],
              ),
            );
          },
        ),
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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _academicYearOptions.contains(_selectedAcademicYear)
                            ? _selectedAcademicYear
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Active school year',
                          border: OutlineInputBorder(),
                        ),
                        items: {..._academicYearOptions, _selectedAcademicYear}
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text(year),
                              ),
                            )
                            .toList(),
                        onChanged: _isSavingAcademicYear
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _selectedAcademicYear = value);
                                }
                              },
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSavingAcademicYear
                          ? null
                          : () => _saveAcademicYear(archivePrevious: false),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save active year'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSavingAcademicYear
                          ? null
                          : _confirmAcademicYearRollover,
                      icon: const Icon(Icons.archive_rounded),
                      label: const Text('Save and archive previous years'),
                    ),
                  ],
                ),
            ],
          ),
        ),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.rate_review_rounded,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluation Reports',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Review teaching, course, system, and simulation feedback.',
                          style: TextStyle(color: _kSubtextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EvaluationReportsPage(),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open reports'),
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

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
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
