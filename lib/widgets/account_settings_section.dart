import 'package:flutter/material.dart';

import '../screens/notification_page.dart';
import 'password_reset_dialog.dart';

class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({
    super.key,
    required this.email,
    required this.role,
    required this.accountDetails,
    required this.onLogout,
    this.showLogout = true,
  });

  final String email;
  final String role;
  final Map<String, String> accountDetails;
  final VoidCallback onLogout;
  final bool showLogout;

  void _showAccountDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account information'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in accountDetails.entries)
                  if (entry.value.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(entry.value),
                        ],
                      ),
                    ),
                Text(
                  'School-managed identity details are read-only. Contact an administrator if they need correction.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Settings',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: const Text('View updates and activity alerts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Account information'),
              subtitle: Text('Review your $role account details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAccountDetails(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Reset password'),
              subtitle: const Text('Receive a secure reset link by email'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showPasswordResetDialog(context, email: email),
            ),
            if (showLogout) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: onLogout,
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
