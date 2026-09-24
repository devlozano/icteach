import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/forum_service.dart';

void main() {
  test(
    'post listener receives edits, counters, deletion and recreation',
    () async {
      final db = FakeFirebaseFirestore();
      final ref = db.doc('classes/class1/forum_posts/post1');
      await ref.set({'title': 'Original', 'content': 'First version'});
      final events = StreamIterator(
        ForumService(firestore: db).watchForumPost('class1', 'post1'),
      );
      addTearDown(events.cancel);
      expect(await events.moveNext(), isTrue);
      expect(events.current!.title, 'Original');
      await ref.update({
        'title': 'Edited',
        'content': 'New version',
        'likeCount': 1,
        'likedBy': ['reader'],
        'replyCount': 2,
        'viewCount': 3,
      });
      expect(await events.moveNext(), isTrue);
      final updated = events.current!;
      expect(updated.title, 'Edited');
      expect(updated.content, 'New version');
      expect(updated.likeCount, 1);
      expect(updated.likedBy, ['reader']);
      expect(updated.replyCount, 2);
      expect(updated.viewCount, 3);
      await ref.delete();
      expect(await events.moveNext(), isTrue);
      expect(events.current, isNull);
      await ref.set({'title': 'Restored'});
      expect(await events.moveNext(), isTrue);
      expect(events.current!.title, 'Restored');
    },
  );
}
