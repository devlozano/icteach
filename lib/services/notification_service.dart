import 'dart:async';
// services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    Stream<String?>? userIds,
    String? Function()? currentUserId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _userIds = userIds,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final FirebaseFirestore _firestore;
  final Stream<String?>? _userIds;
  final String? Function() _currentUserId;

  // Follow auth restoration and account switches instead of caching an empty
  // result when Firebase has not restored the web session yet.
  Stream<List<NotificationModel>> getNotifications() => Stream.multi((output) {
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? records;
    int generation = 0;
    bool cancelled = false;
    final accounts =
        (_userIds ??
                FirebaseAuth.instance.authStateChanges().map(
                  (user) => user?.uid,
                ))
            .distinct()
            .listen((uid) async {
              final current = ++generation;
              await records?.cancel();
              if (cancelled || current != generation) return;
              output.add([]); // Never replay another account's notifications.
              if (uid == null) return;
              records = _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: uid)
                  .snapshots()
                  .listen(
                    (snapshot) {
                      if (cancelled || current != generation) return;
                      final notifications =
                          snapshot.docs
                              .map(NotificationModel.fromFirestore)
                              .toList()
                            ..sort(
                              (a, b) => b.createdAt.compareTo(a.createdAt),
                            );
                      output.add(notifications);
                    },
                    onError: (Object error, StackTrace trace) {
                      if (!cancelled && current == generation)
                        output.addError(error, trace);
                    },
                  );
            }, onError: output.addError);
    output.onCancel = () async {
      cancelled = true;
      generation++;
      await accounts.cancel();
      await records?.cancel();
    };
  });

  Stream<int> getUnreadCount() => getNotifications().map(
    (items) => items.where((item) => !item.isRead).length,
  );

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ markAsRead: $notificationId');
    } catch (e) {
      print('❌ markAsRead error: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final uid = _currentUserId();
    if (uid == null) return;
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .get();
    final unread = snapshot.docs
        .where((doc) => doc.data()['isRead'] != true)
        .toList();
    for (var i = 0; i < unread.length; i += 450) {
      final batch = _firestore.batch();
      for (final doc in unread.skip(i).take(450)) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  // Create a notification
  Future<void> createNotification(NotificationModel notification) async {
    try {
      final docRef = _firestore.collection('notifications').doc();
      final data = {
        'userId': notification.userId,
        'title': notification.title,
        'message': notification.message,
        'type': notification.type,
        'referenceId': notification.referenceId ?? '',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);
      print('✅ createNotification: Created for user ${notification.userId}');
      print('   Title: ${notification.title}');
    } catch (e) {
      print('❌ createNotification error: $e');
    }
  }

  // ✅ FIXED: Get ALL users in class (students, trainers, and teacher)
  Future<List<String>> _getAllUsersInClass(String classId) async {
    final classRef = _firestore.collection('classes').doc(classId);
    final classroom = await classRef.get();
    if (!classroom.exists) return [];
    final data = classroom.data()!;
    final members = await Future.wait([
      classRef.collection('students').get(),
      classRef.collection('trainers').get(),
      _firestore.collection('users').where('role', isEqualTo: 'admin').get(),
    ]);
    final ids = <String>{
      if (data['teacherId'] is String) data['teacherId'] as String,
      ...List<String>.from(data['enrolledStudentIds'] ?? []),
      ...List<String>.from(data['trainerIds'] ?? []),
      for (final group in members)
        for (final doc in group.docs) doc.data()['uid']?.toString() ?? doc.id,
    }..remove('');
    return ids.toList();
  }

  Future<void> _notifyClass(
    String classId,
    String title,
    String message,
    String type, {
    String? excludeUserId,
  }) async {
    final ids = await _getAllUsersInClass(classId);
    final recipients = ids
        .where((id) => id != (excludeUserId ?? _currentUserId()))
        .toList();
    // Firestore limits a batch to 500 writes.
    for (var offset = 0; offset < recipients.length; offset += 450) {
      final batch = _firestore.batch();
      for (final uid in recipients.skip(offset).take(450)) {
        batch.set(_firestore.collection('notifications').doc(), {
          'userId': uid,
          'title': title,
          'message': message,
          'type': type,
          'referenceId': classId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> notifyNewForumPost(
    String classId,
    String postTitle,
    String authorName,
    String excludeUserId,
  ) => _notifyClass(
    classId,
    'New Forum Post: ' + postTitle,
    authorName + ' posted a new discussion.',
    'forum',
    excludeUserId: excludeUserId,
  );

  Future<void> notifyNewForumReply(
    String classId,
    String postTitle,
    String replyAuthor,
    String postAuthorId,
    String excludeUserId,
  ) => _notifyClass(
    classId,
    'New Reply: ' + postTitle,
    replyAuthor + ' replied to a discussion.',
    'forum',
    excludeUserId: excludeUserId,
  );

  Future<void> notifyNewAssignment(String classId, String title) =>
      _notifyClass(
        classId,
        'New Assignment: ' + title,
        'A new assignment has been published.',
        'assignment',
      );

  Future<void> notifyNewQuiz(String classId, String title) => _notifyClass(
    classId,
    'New Quiz: ' + title,
    'A new quiz has been published.',
    'quiz',
  );

  Future<void> notifyNewModule(String classId, String title) => _notifyClass(
    classId,
    'New Module: ' + title,
    'A new learning module has been published.',
    'module',
  );

  // Send grade notification
  Future<void> notifyGrade(
    String studentId,
    String assignmentTitle,
    int score,
  ) async {
    try {
      await createNotification(
        NotificationModel(
          id: '',
          userId: studentId,
          title: 'Assignment Graded: $assignmentTitle',
          message: 'Your assignment has been graded. Score: $score/100',
          type: 'grade',
          referenceId: assignmentTitle,
          createdAt: DateTime.now(),
        ),
      );
      print('✅ notifyGrade: Sent to $studentId');
    } catch (e) {
      print('❌ notifyGrade error: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      print('✅ deleteNotification: $notificationId');
    } catch (e) {
      print('❌ deleteNotification error: $e');
      rethrow;
    }
  }

  // Delete all notifications for a user
  Future<void> deleteAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ deleteAllNotifications: No user logged in');
        return;
      }

      print(
        '🗑️ deleteAllNotifications: Deleting all notifications for ${user.uid}',
      );

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (snapshot.docs.isEmpty) {
        print('ℹ️ deleteAllNotifications: No notifications to delete');
        return;
      }

      print(
        '📊 deleteAllNotifications: Found ${snapshot.docs.length} notifications to delete',
      );

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print(
        '✅ deleteAllNotifications: Successfully deleted ${snapshot.docs.length} notifications',
      );
    } catch (e) {
      print('❌ deleteAllNotifications error: $e');
      rethrow;
    }
  }

  // Check if user has any notifications
  Future<bool> hasNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ hasNotifications error: $e');
      return false;
    }
  }

  // Get notification count
  Future<int> getNotificationCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ getNotificationCount error: $e');
      return 0;
    }
  }

  // ✅ Debug method to check class users
  Future<void> debugClassUsers(String classId) async {
    try {
      print('🔍 ===== DEBUG: Checking all users in class $classId =====');

      // Get class document
      final classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();
      if (classDoc.exists) {
        final data = classDoc.data() ?? {};
        print('📚 Class: ${data['name']}');
        print('👨‍🏫 Teacher: ${data['teacherId']}');

        final enrolledIds = List<String>.from(data['enrolledStudentIds'] ?? []);
        print('📊 enrolledStudentIds: ${enrolledIds.length}');
        for (final id in enrolledIds) {
          final userDoc = await _firestore.collection('users').doc(id).get();
          if (userDoc.exists) {
            final userData = userDoc.data() ?? {};
            print(
              '   ✅ Student: ${userData['displayName'] ?? userData['name'] ?? id}',
            );
          } else {
            print('   ❌ User not found: $id');
          }
        }
      }

      // Check students subcollection
      final studentsSnapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .get();

      print('📊 students subcollection: ${studentsSnapshot.docs.length}');
      for (final doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final uid = data['uid']?.toString() ?? doc.id;
        final name = data['name']?.toString() ?? 'Unknown';
        final role = data['role']?.toString() ?? 'student';
        print('   👤 $name (UID: $uid, Role: $role)');
      }

      print('🔍 ===== DEBUG COMPLETE =====');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }
}
