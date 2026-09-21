import 'package:flutter/material.dart';
import '../services/forum_service.dart';

Future<void> showForumViewersDialog(
  BuildContext context,
  ForumService service,
  String classId,
  String postId,
  int count,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text('Viewed by (' + count.toString() + ')'),
    content: SizedBox(
      width: 360,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.getPostViewers(classId, postId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text('Could not load viewers.');
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final viewers = snapshot.data!;
          if (viewers.isEmpty) return const Text('No views yet.');
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final viewer in viewers)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (viewer['name']?.toString() ?? 'User')
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(viewer['name']?.toString() ?? 'User'),
                    subtitle: Text(viewer['role']?.toString() ?? 'student'),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Close'),
      ),
    ],
  ),
);
