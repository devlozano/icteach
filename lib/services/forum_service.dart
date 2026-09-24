import 'workspace_data.dart';
// services/forum_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/forum_model.dart';
import 'notification_service.dart';

class ForumService {
  ForumService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  late final NotificationService _notificationService = NotificationService(
    firestore: _firestore,
  );

  // Get forum posts for a class
  Stream<List<ForumPost>> getForumPosts(String classId) {
    return WorkspaceData.watch(
      'forumPosts/$classId',
      () => _firestore
          .collection('classes')
          .doc(classId)
          .collection('forum_posts')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ForumPost.fromFirestore(doc))
                .toList();
          }),
    );
  }

  Stream<ForumPost?> watchForumPost(String classId, String postId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists ? ForumPost.fromFirestore(doc) : null);
  }

  // Get a single post with replies
  Future<ForumPost> getForumPost(String classId, String postId) async {
    final doc = await _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .get();

    if (!doc.exists) {
      throw Exception('Post not found');
    }

    return ForumPost.fromFirestore(doc);
  }

  // Create a new forum post with notification
  Future<void> createPost(ForumPost post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get user role from users collection
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    String authorRole = userData['role']?.toString() ?? 'student';
    String authorName =
        userData['displayName']?.toString() ??
        userData['name']?.toString() ??
        user.displayName ??
        'Unknown';

    print('📝 Creating post - User: $authorName, Role: $authorRole');

    final postRef = _firestore
        .collection('classes')
        .doc(post.classId)
        .collection('forum_posts')
        .doc();

    final newPost = post.copyWith(
      id: postRef.id,
      authorName: authorName,
      authorRole: authorRole,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likeCount: 0,
      likedBy: [],
      viewCount: 0,
      replyCount: 0,
    );

    await postRef.set(newPost.toFirestore());

    // ✅ Send notification to all users EXCEPT the poster
    await _notificationService.notifyNewForumPost(
      post.classId,
      post.title,
      authorName,
      user.uid,
      postId: post.id,
    );

    // Debug: Check if notifications were created
    await _notificationService.debugClassUsers(post.classId);
  }

  // Like a post
  Future<void> toggleLikePost(String classId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postRef = _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId);

    final doc = await postRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = likedBy.contains(user.uid);

    if (isLiked) {
      await postRef.update({
        'likedBy': FieldValue.arrayRemove([user.uid]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await postRef.update({
        'likedBy': FieldValue.arrayUnion([user.uid]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  // Count one view per signed-in user for each post. The viewer document is the idempotency key.
  Future<void> incrementViewCount(String classId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final postRef = _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId);
    final viewerRef = postRef.collection('viewers').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final viewer = await transaction.get(viewerRef);
      if (viewer.exists) return;
      final profileRef = _firestore.collection('users').doc(user.uid);
      final profile = await transaction.get(profileRef);
      final data = profile.data() ?? const <String, dynamic>{};
      transaction.set(viewerRef, {
        'userId': user.uid,
        'name':
            data['displayName']?.toString() ??
            data['name']?.toString() ??
            user.displayName ??
            user.email ??
            'User',
        'role': data['role']?.toString() ?? 'student',
        'viewedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(postRef, {'viewCount': FieldValue.increment(1)});
    });
  }

  Stream<List<Map<String, dynamic>>> getPostViewers(
    String classId,
    String postId,
  ) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .collection('viewers')
        .orderBy('viewedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  // Get replies for a post
  Stream<List<ForumReply>> getReplies(String classId, String postId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ForumReply.fromFirestore(doc))
              .toList();
        });
  }

  // Add a reply with notification
  Future<void> addReply(String classId, String postId, String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get post to know the author
    final post = await getForumPost(classId, postId);

    // Get user role and name
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final authorRole = userData['role']?.toString() ?? 'student';
    final authorName =
        userData['displayName']?.toString() ??
        userData['name']?.toString() ??
        user.displayName ??
        'Unknown';

    final replyRef = _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .collection('replies')
        .doc();

    final reply = ForumReply(
      id: replyRef.id,
      postId: postId,
      content: content,
      authorId: user.uid,
      authorName: authorName,
      authorRole: authorRole,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likeCount: 0,
      likedBy: [],
    );

    await replyRef.set(reply.toFirestore());

    // Update reply count on post
    await _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .update({
          'replyCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // ✅ Send notification to all users in class EXCEPT the replier
    await _notificationService.notifyNewForumReply(
      classId,
      post.title,
      authorName,
      post.authorId,
      user.uid,
      postId: post.id,
    );

    print('✅ Reply notification sent for post: ${post.title}');
  }

  // Like a reply
  Future<void> toggleLikeReply(
    String classId,
    String postId,
    String replyId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final replyRef = _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .collection('replies')
        .doc(replyId);

    final doc = await replyRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = likedBy.contains(user.uid);

    if (isLiked) {
      await replyRef.update({
        'likedBy': FieldValue.arrayRemove([user.uid]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await replyRef.update({
        'likedBy': FieldValue.arrayUnion([user.uid]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  // Delete a post (only by author or teacher)
  Future<void> deletePost(String classId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user is author or teacher
    final post = await getForumPost(classId, postId);
    if (post.authorId != user.uid) {
      // Check if user is teacher
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final role = userData['role']?.toString() ?? 'student';
      if (role != 'teacher' && role != 'trainer') {
        throw Exception('Only the author or teacher can delete this post');
      }
    }

    // Delete all replies first
    final repliesSnapshot = await _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId)
        .collection('replies')
        .get();

    final batch = _firestore.batch();
    for (final doc in repliesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the post
    final postRef = _firestore
        .collection('classes')
        .doc(classId)
        .collection('forum_posts')
        .doc(postId);
    batch.delete(postRef);

    await batch.commit();
    await _notificationService.deleteForReference(
      referenceId: postId,
      type: 'forum',
    );
  }
}
