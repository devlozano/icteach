import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/school_profile.dart';
import '../admin_login.dart';
import 'persistent_workspace.dart';
import 'staff_workspace_header.dart';

const principalPanelLabels = <String>[
  'Dashboard',
  'Manage Users',
  'Manage Classes',
  'Content Overview',
  'Performance',
  'Reports',
  'Feedback',
  'School Profile',
  'Settings',
];

const _navColor = Color(0xFF0F172A);
const _accent = Color(0xFF0891B2);
const _pageBackground = Color(0xFFF1F5F9);

class PrincipalWorkspaceNavigation {
  static ValueChanged<String>? _selectPanel;

  static void register(ValueChanged<String> callback) {
    _selectPanel = callback;
  }

  static void select(BuildContext context, String label) {
    final callback = _selectPanel;
    if (callback == null) {
      Navigator.maybePop(context);
      return;
    }
    PersistentWorkspace.returnHome(context, () => callback(label));
  }
}

class PrincipalSidebar extends StatelessWidget {
  const PrincipalSidebar({
    super.key,
    required this.currentSelection,
    required this.onSelected,
  });

  final String currentSelection;
  final ValueChanged<String> onSelected;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    PersistentWorkspace.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_navColor, Color(0xFF162A3D)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  child: Image.asset(
                    'assets/ict_logo.png',
                    fit: BoxFit.contain,
                  ),
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'PRINCIPAL WORKSPACE',
                    style: TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(Icons.dashboard_rounded, 'Dashboard'),
                  _item(Icons.people_alt_rounded, 'Manage Users'),
                  _item(Icons.class_rounded, 'Manage Classes'),
                  _item(Icons.menu_book_rounded, 'Content Overview'),
                  _item(Icons.bar_chart_rounded, 'Performance'),
                  _item(Icons.assessment_rounded, 'Reports'),
                  _item(Icons.rate_review_outlined, 'Feedback'),
                  _item(Icons.school_outlined, 'School Profile'),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 20),
            _item(Icons.settings_rounded, 'Settings'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: DefaultTextStyle(
                      style: TextStyle(color: Colors.white),
                      child: SchoolIdentity(compact: true),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () => _signOut(context),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white70,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _item(IconData icon, String label) => _PrincipalNavTile(
    icon: icon,
    label: label,
    selected: currentSelection == label,
    onTap: () => onSelected(label),
  );
}

class _PrincipalNavTile extends StatelessWidget {
  const _PrincipalNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF67E8F9) : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: .08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                SizedBox(width: 32, child: Icon(icon, color: color, size: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
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
                      color: _accent,
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

class PrincipalDetailScaffold extends StatelessWidget {
  const PrincipalDetailScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.maxWidth = 980,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      final compact = constraints.maxWidth < 600;
      return Scaffold(
        backgroundColor: _pageBackground,
        drawer: wide
            ? null
            : Drawer(
                child: PrincipalSidebar(
                  currentSelection: 'Manage Users',
                  onSelected: (label) {
                    Navigator.of(context).pop();
                    PrincipalWorkspaceNavigation.select(context, label);
                  },
                ),
              ),
        body: SafeArea(
          child: Column(
            children: [
              StaffTopBar(
                name: 'Principal',
                role: 'Principal',
                showIdentity: false,
                showNotifications: false,
                showMenuButton: !wide,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 28,
                    compact ? 14 : 24,
                    compact ? 12 : 28,
                    compact ? 24 : 36,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to Manage Users'),
                          ),
                          const SizedBox(height: 8),
                          StaffPageHeading(
                            title: title,
                            subtitle: subtitle,
                            icon: icon,
                          ),
                          const SizedBox(height: 20),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
