import 'package:flutter/material.dart';
import '../admin/school_profile.dart';
import '../screens/notification_page.dart';
import 'notification_badge.dart';

const _kCardBorder = Color(0xFFDCE4EC);
const _kAccentBlue = Color(0xFF0891B2);
const _kSubtextColor = Color(0xFF64748B);
const _kNavColor = Color(0xFF0F172A);

class StaffPageHeading extends StatelessWidget {
  const StaffPageHeading({
    super.key,
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

class StaffTopBar extends StatelessWidget {
  const StaffTopBar({
    super.key,
    required this.name,
    required this.showMenuButton,
    this.role = 'Administration',
    this.showIdentity = true,
  });
  final String name;
  final String role;
  final bool showMenuButton;
  final bool showIdentity;

  @override
  Widget build(BuildContext context) {
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
                '$role Workspace',
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
          if (showIdentity) ...[
            const SizedBox(width: 8),
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
              child: SizedBox(
                width: width < 400 ? 150 : 210,
                child: role == 'Administration'
                    ? const SchoolIdentity(compact: true)
                    : Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD CONTENT
// ═══════════════════════════════════════════════════════════════════════════════
