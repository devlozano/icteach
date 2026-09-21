import '../../widgets/fullscreen_image_viewer.dart';
// screens/student/forums_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/forum_model.dart';
import '../../services/forum_service.dart';
import 'create_forum_post_page.dart';
import 'forum_detail_page.dart';

class ForumsPage extends StatefulWidget {
  final String classId;
  final String className;

  const ForumsPage({super.key, required this.classId, required this.className});

  @override
  State<ForumsPage> createState() => _ForumsPageState();
}

class _ForumsPageState extends State<ForumsPage> {
  final ForumService _forumService = ForumService();
  String? _currentUserId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((
        doc,
      ) {
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _currentUserRole = data?['role']?.toString() ?? 'student';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text('Forums - ${widget.className}'),
        backgroundColor: const Color(0xFF428DEB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateForumPostPage(
                    classId: widget.classId,
                    className: widget.className,
                  ),
                ),
              ).then((_) => setState(() {}));
            },
            icon: const Icon(Icons.add),
            tooltip: 'Create Post',
          ),
        ],
      ),
      body: StreamBuilder<List<ForumPost>>(
        stream: _forumService.getForumPosts(widget.classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to start a discussion',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateForumPostPage(
                            classId: widget.classId,
                            className: widget.className,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF428DEB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              // ✅ Ensure role is correctly set from post data
              // If role is empty or 'student' but user is actually a teacher/trainer,
              // we need to fetch the correct role
              return FutureBuilder<ForumPost>(
                future: _ensureCorrectRole(post),
                builder: (context, roleSnapshot) {
                  final displayPost = roleSnapshot.data ?? post;
                  return _ForumPostCard(
                    post: displayPost,
                    currentUserId: _currentUserId,
                    onTap: () => _viewPost(context, displayPost),
                    onViews: () => _showViewers(context, displayPost),
                    onLike: () => _toggleLike(displayPost),
                    onDelete: () => _deletePost(displayPost),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateForumPostPage(
                classId: widget.classId,
                className: widget.className,
              ),
            ),
          ).then((_) => setState(() {}));
        },
        backgroundColor: const Color(0xFF428DEB),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ✅ Helper method to ensure correct role
  Future<void> _showViewers(BuildContext context, ForumPost post) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.visibility_outlined),
            const SizedBox(width: 8),
            Text('Viewed by (' + post.viewCount.toString() + ')'),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _forumService.getPostViewers(widget.classId, post.id),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Text('Could not load viewers.');
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final viewers = snapshot.data!;
              if (viewers.isEmpty) return const Text('No views yet.');
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: viewers.length,
                  itemBuilder: (_, index) {
                    final viewer = viewers[index];
                    final name = viewer['name']?.toString() ?? 'User';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        child: Text(name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(name),
                      subtitle: Text(viewer['role']?.toString() ?? 'student'),
                    );
                  },
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
  }

  Future<ForumPost> _ensureCorrectRole(ForumPost post) async {
    // If role is already set correctly (teacher or trainer), return as is
    if (post.authorRole == 'teacher' || post.authorRole == 'trainer') {
      return post;
    }

    // If role is 'student' or empty, try to fetch from users collection
    if (post.authorRole == 'student' || post.authorRole.isEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(post.authorId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final actualRole = userData?['role']?.toString() ?? 'student';
          final displayName =
              userData?['displayName']?.toString() ??
              userData?['name']?.toString() ??
              post.authorName;

          // Return a new post with corrected role and name
          return post.copyWith(authorRole: actualRole, authorName: displayName);
        }
      } catch (e) {
        print('Error fetching user role: $e');
      }
    }

    return post;
  }

  void _viewPost(BuildContext context, ForumPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ForumDetailPage(classId: widget.classId, postId: post.id),
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _toggleLike(ForumPost post) async {
    await _forumService.toggleLikePost(widget.classId, post.id);
    // ✅ Force a rebuild to update the like count
    setState(() {});
  }

  Future<void> _deletePost(ForumPost post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user is author or teacher
    if (post.authorId != user.uid &&
        _currentUserRole != 'teacher' &&
        _currentUserRole != 'trainer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the author or teacher can delete this post'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _forumService.deletePost(widget.classId, post.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Forum Post Card
class _ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final String? currentUserId;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onViews;
  final VoidCallback onDelete;

  const _ForumPostCard({
    required this.post,
    this.currentUserId,
    required this.onTap,
    required this.onLike,
    required this.onViews,
    required this.onDelete,
  });

  Widget _buildRoleTag(String role) {
    Color color;
    String label;
    switch (role.toLowerCase()) {
      case 'teacher':
        color = Colors.blue;
        label = '👨‍🏫 Teacher';
        break;
      case 'trainer':
        color = Colors.purple;
        label = '👑 Trainer';
        break;
      default:
        color = Colors.grey;
        label = '🎓 Student';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = post.likedBy.contains(currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author Info with Role Tag
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: post.authorRole == 'teacher'
                        ? Colors.blue.shade100
                        : post.authorRole == 'trainer'
                        ? Colors.purple.shade100
                        : Colors.grey.shade100,
                    radius: 16,
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: post.authorRole == 'teacher'
                            ? Colors.blue.shade700
                            : post.authorRole == 'trainer'
                            ? Colors.purple.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildRoleTag(post.authorRole),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(post.createdAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Content Preview
              Text(
                post.content,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              if (post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.imageUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final imageUrl = post.imageUrls[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => showFullscreenImageGallery(
                            context,
                            post.imageUrls,
                            initialIndex: index,
                          ),
                          child: Image.network(
                            imageUrl,
                            width: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 180,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Stats: Replies, Views, Likes
              Row(
                children: [
                  // Replies
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.replyCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 16),

                  // Views
                  InkWell(
                    onTap: onViews,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.viewCount.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Likes (clickable)
                  GestureDetector(
                    onTap: onLike,
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: isLiked ? Colors.red : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likeCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Delete button (only for author)
                  if (currentUserId == post.authorId)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete Post',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
