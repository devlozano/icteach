import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:icteach/services/notification_service.dart';
import 'package:icteach/models/notification_model.dart';
import 'package:icteach/screens/notification_page.dart';
import 'package:icteach/screens/student/forum_detail_page.dart';
import 'package:icteach/screens/student/module_view_page.dart';

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'notifications follow restored login, every role and logout without leaking accounts',
    () async {
      final db = FakeFirebaseFirestore();
      final accounts = StreamController<String?>.broadcast();
      for (final role in ['admin', 'teacher', 'trainer', 'student']) {
        await db.collection('notifications').doc(role).set({
          'userId': role,
          'title': role,
          'isRead': false,
        });
      }
      final service = NotificationService(
        firestore: db,
        userIds: accounts.stream,
      );
      final events = <List<NotificationModel>>[];
      final subscription = service.getNotifications().listen(events.add);
      accounts.add(null);
      await flush();
      expect(events.last, isEmpty);
      for (final role in ['admin', 'teacher', 'trainer', 'student']) {
        accounts.add(role);
        await flush();
        expect(events.last.map((n) => n.id), [role]);
      }
      accounts.add(null);
      await flush();
      expect(events.last, isEmpty);
      await db.collection('notifications').doc('student').update({
        'title': 'Changed',
      });
      await flush();
      expect(events.last, isEmpty);
      await subscription.cancel();
      await accounts.close();
    },
  );
  test(
    'unread count includes legacy records and reflects mark-all-read for only current user',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('notifications').doc('legacy').set({
        'userId': 'trainer',
      });
      await db.collection('notifications').doc('new').set({
        'userId': 'trainer',
        'isRead': false,
      });
      await db.collection('notifications').doc('other').set({
        'userId': 'student',
        'isRead': false,
      });
      final service = NotificationService(
        firestore: db,
        userIds: Stream.value('trainer'),
        currentUserId: () => 'trainer',
      );
      final counts = <int>[];
      final sub = service.getUnreadCount().listen(counts.add);
      await flush();
      expect(counts.last, 2);
      await service.markAllAsRead();
      await flush();
      expect(counts.last, 0);
      expect(
        (await db.collection('notifications').doc('other').get())
            .data()!['isRead'],
        false,
      );
      await sub.cancel();
    },
  );
  test(
    'published activity reaches students, trainers, teachers and admin without duplicate recipients',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('admin').set({'role': 'admin'});
      final classroom = db.collection('classes').doc('class');
      await classroom.set({
        'teacherId': 'teacher',
        'enrolledStudentIds': ['student', 'trainer'],
      });
      await classroom.collection('students').doc('student').set({
        'uid': 'student',
      });
      await classroom.collection('trainers').doc('trainer').set({
        'uid': 'trainer',
      });
      final service = NotificationService(
        firestore: db,
        currentUserId: () => 'publisher',
      );
      await service.notifyNewModule('class', 'Module');
      final docs = (await db.collection('notifications').get()).docs;
      expect(docs.map((d) => d.data()['userId']).toSet(), {
        'admin',
        'teacher',
        'trainer',
        'student',
      });
      expect(docs.length, 4);
      expect(docs.every((doc) => doc.data()['classId'] == 'class'), isTrue);
      await service.notifyNewForumPost('class', 'Post', 'Teacher', 'teacher');
      final forums =
          (await db
                  .collection('notifications')
                  .where('type', isEqualTo: 'forum')
                  .get())
              .docs;
      expect(forums.map((d) => d.data()['userId']).toSet(), {
        'admin',
        'trainer',
        'student',
      });
      expect(forums.every((doc) => doc.data()['classId'] == 'class'), isTrue);
      expect(
        forums.every((doc) => doc.data()['referenceId'] == 'class'),
        isTrue,
      );
    },
  );
  test(
    'forum notifications keep class ID separate from post reference',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('classes').doc('networking').set({
        'enrolledStudentIds': ['student'],
      });
      final service = NotificationService(
        firestore: db,
        currentUserId: () => 'teacher',
      );

      await service.notifyNewForumPost(
        'networking',
        'Cable standards',
        'Teacher',
        'teacher',
        postId: 'post-1',
      );

      final doc = (await db.collection('notifications').get()).docs.single;
      final notification = NotificationModel.fromFirestore(doc);
      expect(notification.classId, 'networking');
      expect(notification.referenceId, 'post-1');
      expect(await service.resolveClassId(notification), 'networking');
    },
  );

  test('legacy forum notification resolves class through its post', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('classes').doc('legacy-class').set({
      'name': 'Legacy Class',
    });
    await db
        .collection('classes')
        .doc('legacy-class')
        .collection('forum_posts')
        .doc('legacy-post')
        .set({'title': 'Old post', 'classId': 'legacy-class'});
    await db.collection('notifications').doc('legacy-forum').set({
      'userId': 'student',
      'type': 'forum',
      'title': 'New Forum Post: Old post',
      'referenceId': '',
    });
    final service = NotificationService(firestore: db);
    final notification = NotificationModel.fromFirestore(
      await db.collection('notifications').doc('legacy-forum').get(),
    );

    expect(await service.resolveClassId(notification), 'legacy-class');
  });
  test('delivery splits large classes into batches', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('classes').doc('large').set({
      'enrolledStudentIds': List.generate(
        510,
        (i) => 'student-' + i.toString(),
      ),
    });
    await NotificationService(
      firestore: db,
      currentUserId: () => 'author',
    ).notifyNewQuiz('large', 'Quiz');
    expect((await db.collection('notifications').get()).docs.length, 510);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'notification click opens its direct destination at width ' +
          width.toString(),
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        await db.collection('notifications').doc('forum').set({
          'userId': 'student',
          'title': 'New Forum Post: Cable test',
          'type': 'forum',
          'classId': 'class-1',
          'referenceId': 'post-1',
          'isRead': false,
        });
        final service = NotificationService(
          firestore: db,
          userIds: Stream.value('student'),
          currentUserId: () => 'student',
        );
        Widget? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPage(
              service: service,
              loadRole: () async => 'student',
              loadClass: (_) async => {'name': 'Networking'},
              openDestination: (_, destination) => opened = destination,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Forum Post: Cable test'));
        await tester.pumpAndSettle();

        expect(opened, isA<ForumDetailPage>());
        final page = opened! as ForumDetailPage;
        expect(page.classId, 'class-1');
        expect(page.postId, 'post-1');
      },
    );
    testWidgets(
      'module notification opens the student module page at width ' +
          width.toString(),
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        await db.collection('notifications').doc('module').set({
          'userId': 'student',
          'title': 'New Module: Networking',
          'type': 'module',
          'classId': 'class-1',
          'referenceId': 'class-1',
          'isRead': false,
        });
        final service = NotificationService(
          firestore: db,
          userIds: Stream.value('student'),
          currentUserId: () => 'student',
        );
        Widget? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPage(
              service: service,
              loadRole: () async => 'student',
              loadClass: (_) async => {'name': 'Networking'},
              openDestination: (_, destination) => opened = destination,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Module: Networking'));
        await tester.pumpAndSettle();

        expect(opened, isA<ModuleViewPage>());
        final page = opened! as ModuleViewPage;
        expect(page.classId, 'class-1');
        expect(page.className, 'Networking');
      },
    );
    testWidgets(
      'grade notification opens a mounted dialog at width ' + width.toString(),
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        await db.collection('notifications').doc('grade').set({
          'userId': 'student',
          'title': 'Grade ready',
          'type': 'grade',
          'message': 'Score: 90',
          'referenceId': 'Assignment title',
        });
        final service = NotificationService(
          firestore: db,
          userIds: Stream.value('student'),
          currentUserId: () => 'student',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPage(
              service: service,
              loadRole: () async => 'student',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Grade ready'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Notifications'), findsOneWidget);
        expect(
          (await db.collection('notifications').doc('grade').get())
              .data()!['isRead'],
          true,
        );
      },
    );
  }
}
