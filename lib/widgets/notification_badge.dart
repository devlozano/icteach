import '../services/workspace_data.dart';
// widgets/notification_badge.dart
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;

  const NotificationBadge({super.key, required this.child});

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: WorkspaceData.watch(
        'unreadNotifications',
        () => WorkspaceData.watch(
          'notifications',
          _notificationService.getNotifications,
        ).map((items) => items.where((item) => !item.isRead).length),
      ),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          children: [
            widget.child,
            if (count > 0 || snapshot.hasError)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    snapshot.hasError
                        ? '!'
                        : count > 99
                        ? '99+'
                        : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
