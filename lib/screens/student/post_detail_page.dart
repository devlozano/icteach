import '../../widgets/forum_viewers_dialog.dart';
// screens/student/forum_detail_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/forum_model.dart';
import '../../services/forum_service.dart';

class ForumDetailPage extends StatefulWidget {
  final String classId;
  final String postId;

  const ForumDetailPage({
    super.key,
    required this.classId,
    required this.postId,
  });

  @override
  State<ForumDetailPage> createState() => _ForumDetailPageState();
}

class _ForumDetailPageState extends State<ForumDetailPage> {
  final ForumService _forumService = ForumService();
  final TextEditingController _replyController = TextEditingController();
  bool _isLoading = false;
  late ForumPost _post;
  bool _isPostLoaded = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadPost();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  Future<void> _loadPost() async {
    try {
      final post = await _forumService.getForumPost(
        widget.classId,
        widget.postId,
      );
      setState(() {
        _post = post;
        _isPostLoaded = true;
      });

      // Increment view count
      await _forumService.incrementViewCount(widget.classId, widget.postId);
      final refreshed = await _forumService.getForumPost(
        widget.classId,
        widget.postId,
      );
      if (mounted) setState(() => _post = refreshed);
    } catch (e) {
      print('Error loading post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _forumService.addReply(widget.classId, widget.postId, content);
      _replyController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reply added!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLikePost() async {
    await _forumService.toggleLikePost(widget.classId, widget.postId);
  }

  Future<void> _toggleLikeReply(String replyId) async {
    await _forumService.toggleLikeReply(widget.classId, widget.postId, replyId);
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text('Forum Post'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _isPostLoaded
          ? Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                _post.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Author info with role tag
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        _post.authorRole == 'teacher'
                                        ? Colors.blue.shade100
                                        : _post.authorRole == 'trainer'
                                        ? Colors.purple.shade100
                                        : Colors.grey.shade100,
                                    child: Text(
                                      _post.authorName.isNotEmpty
                                          ? _post.authorName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _post.authorRole == 'teacher'
                                            ? Colors.blue.shade700
                                            : _post.authorRole == 'trainer'
                                            ? Colors.purple.shade700
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _post.authorName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildRoleTag(_post.authorRole),
                                          ],
                                        ),
                                        Text(
                                          _formatDate(_post.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Content
                              Text(
                                _post.content,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Stats (views, replies, likes)
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => showForumViewersDialog(
                                      context,
                                      _forumService,
                                      widget.classId,
                                      widget.postId,
                                      _post.viewCount,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _post.viewCount.toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_post.replyCount}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: _toggleLikePost,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _post.likedBy.contains(_currentUserId)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 18,
                                          color:
                                              _post.likedBy.contains(
                                                _currentUserId,
                                              )
                                              ? Colors.red
                                              : Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_post.likeCount}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Replies Section
                        const Text(
                          'Replies',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Replies List
                        StreamBuilder<List<ForumReply>>(
                          stream: _forumService.getReplies(
                            widget.classId,
                            widget.postId,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final replies = snapshot.data ?? [];

                            if (replies.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                alignment: Alignment.center,
                                child: Text(
                                  'No replies yet. Be the first to reply!',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: replies.length,
                              itemBuilder: (context, index) {
                                final reply = replies[index];
                                final isLiked = reply.likedBy.contains(
                                  _currentUserId,
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                reply.authorRole == 'teacher'
                                                ? Colors.blue.shade100
                                                : reply.authorRole == 'trainer'
                                                ? Colors.purple.shade100
                                                : Colors.grey.shade100,
                                            child: Text(
                                              reply.authorName.isNotEmpty
                                                  ? reply.authorName[0]
                                                        .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    reply.authorRole ==
                                                        'teacher'
                                                    ? Colors.blue.shade700
                                                    : reply.authorRole ==
                                                          'trainer'
                                                    ? Colors.purple.shade700
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Text(
                                                  reply.authorName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                _buildRoleTag(reply.authorRole),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatDate(reply.createdAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        reply.content,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 6),
                                      // Like button for reply
                                      GestureDetector(
                                        onTap: () => _toggleLikeReply(reply.id),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: 14,
                                              color: isLiked
                                                  ? Colors.red
                                                  : Colors.grey.shade400,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${reply.likeCount}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Reply Input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF428DEB),
                        child: IconButton(
                          onPressed: _isLoading ? null : _addReply,
                          icon: Icon(
                            _isLoading ? Icons.hourglass_empty : Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
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
