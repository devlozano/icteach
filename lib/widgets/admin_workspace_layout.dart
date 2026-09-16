import 'package:flutter/material.dart';
import 'staff_workspace_header.dart';

/// Copies the admin scaffold, breakpoints, header, spacing and page scrolling.
/// Teacher and trainer call this only from their kIsWeb branch.
class AdminWorkspaceLayout extends StatelessWidget {
  const AdminWorkspaceLayout({
    super.key,
    required this.sidebarBuilder,
    required this.topBarBuilder,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final Widget Function(VoidCallback closeDrawer) sidebarBuilder;
  final Widget Function(bool showMenu) topBarBuilder;
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 1000;
      final isCompact = constraints.maxWidth < 600;
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        drawer: isWide
            ? null
            : Drawer(
                child: Builder(
                  builder: (context) =>
                      sidebarBuilder(() => Navigator.of(context).pop()),
                ),
              ),
        body: SafeArea(
          child: Row(
            children: [
              if (isWide) sidebarBuilder(() {}),
              Expanded(
                child: Column(
                  children: [
                    topBarBuilder(!isWide),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 12 : 28,
                          isCompact ? 14 : 24,
                          isCompact ? 12 : 28,
                          isCompact ? 24 : 36,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StaffPageHeading(
                                title: title,
                                subtitle: subtitle,
                                icon: icon,
                              ),
                              const SizedBox(height: 20),
                              child,
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
}
