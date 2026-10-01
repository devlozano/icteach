import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/forum_service.dart';

Future<void> showForumViewersDialog(
  BuildContext context,
  ForumService service,
  String classId,
  String postId,
  String authorId,
) => showDialog<void>(
  context: context,
  builder: (_) => ForumViewersDialog(
    viewers: service.getPostViewers(classId, postId, authorId),
  ),
);

class ForumViewersDialog extends StatelessWidget {
  const ForumViewersDialog({super.key, required this.viewers});

  final Stream<List<Map<String, dynamic>>> viewers;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff0b2b4a), Color(0xff174e78)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.visibility_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viewed by',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'People who opened this discussion',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Flexible(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: viewers,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _ViewerState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load viewers',
                    message:
                        'Check your connection and try opening this again.',
                    color: Color(0xffc53b3b),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const _ViewerState(
                    icon: Icons.visibility_off_outlined,
                    title: 'No other viewers yet',
                    message:
                        'Viewer accounts will appear here after they open the post.',
                    color: Color(0xff64748b),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            items.length == 1
                                ? '1 viewer'
                                : '${items.length} viewers',
                            style: const TextStyle(
                              color: Color(0xff334155),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: Color(0xff94a3b8),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Post author excluded',
                                style: TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) =>
                            _ViewerTile(viewer: items[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ViewerTile extends StatelessWidget {
  const _ViewerTile({required this.viewer});

  final Map<String, dynamic> viewer;

  DateTime? get viewedAt {
    final value = viewer['viewedAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = viewer['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'User' : name;
    final role = viewer['role']?.toString().trim().toLowerCase() ?? 'student';
    final roleLabel = role.isEmpty
        ? 'Student'
        : '${role[0].toUpperCase()}${role.substring(1)}';
    final date = viewedAt;
    final roleColor = switch (role) {
      'teacher' => const Color(0xff2563eb),
      'trainer' => const Color(0xff7c3aed),
      'admin' => const Color(0xffc2410c),
      _ => const Color(0xff16845b),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: roleColor.withValues(alpha: .12),
            child: Text(
              displayName.characters.first.toUpperCase(),
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff0f172a),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Viewed ${DateFormat('MMM d, h:mm a').format(date)}',
                    style: const TextStyle(
                      color: Color(0xff64748b),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                color: roleColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerState extends StatelessWidget {
  const _ViewerState({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff64748b), height: 1.4),
        ),
      ],
    ),
  );
}
