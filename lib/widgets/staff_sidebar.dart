import '../admin/school_profile.dart';
import 'package:flutter/material.dart';

class StaffSidebar extends StatelessWidget {
  final String role, name;
  final int selectedIndex;
  final List<(IconData, String)> items;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final VoidCallback? onNotifications;
  const StaffSidebar({
    super.key,
    required this.role,
    required this.name,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
    required this.onLogout,
    this.onNotifications,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 256,
    child: Material(
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.school_rounded,
                    color: Color(0xFF67E8F9),
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ICTeach',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$role workspace',
              style: const TextStyle(color: Color(0xFFB5CDE2), fontSize: 13),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selectedIndex == i
                      ? const Color(0xFF0891B2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    selected: selectedIndex == i,
                    minVerticalPadding: 14,
                    leading: Icon(
                      items[i].$1,
                      color: selectedIndex == i
                          ? Colors.white
                          : const Color(0xFFB5CDE2),
                    ),
                    title: Text(
                      items[i].$2,
                      style: TextStyle(
                        color: selectedIndex == i
                            ? Colors.white
                            : const Color(0xFFDFEAF5),
                        fontWeight: selectedIndex == i
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: selectedIndex == i
                        ? const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                    onTap: () => onSelected(i),
                  ),
                ),
              ),
            if (onNotifications != null)
              ListTile(
                leading: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFFB5CDE2),
                ),
                title: const Text(
                  'Notifications',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: onNotifications,
              ),
            const SizedBox(height: 28),
            const Divider(color: Color(0xFF36506B)),
            if (role == 'Admin')
              const DefaultTextStyle(
                style: TextStyle(color: Colors.white),
                child: SchoolIdentity(compact: true),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  role,
                  style: const TextStyle(color: Color(0xFFB5CDE2)),
                ),
              ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFDA4AF),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}
