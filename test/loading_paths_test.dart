import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:icteach/services/live_stream_cache.dart';
import 'package:icteach/services/assigned_classes.dart';
import 'package:icteach/widgets/lazy_indexed_stack.dart';
import 'package:icteach/widgets/retained_future_builder.dart';

void main() {
  test(
    'three page listeners use one source and replay current data on return',
    () async {
      final cache = LiveStreamCache();
      final source = StreamController<int>();
      int starts = 0;
      Stream<int> load() {
        starts++;
        return source.stream;
      }

      final stream = cache.watch('classes', load);
      final a = <int>[], b = <int>[];
      final first = stream.listen(a.add);
      final second = cache.watch('classes', load).listen(b.add);
      source.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(starts, 1);
      expect(a, [1]);
      expect(b, [1]);
      await first.cancel();
      await second.cancel();
      expect(await cache.watch('classes', load).first, 1);
      final next = stream.firstWhere((value) => value == 2);
      source.add(2);
      expect(await next, 2);
      expect(starts, 1);
      await cache.clear();
      await source.close();
    },
  );
  test(
    'clearing session cancels old source and never replays old account data',
    () async {
      final cache = LiveStreamCache();
      bool cancelled = false;
      final source = StreamController<int>(onCancel: () => cancelled = true);
      final old = cache.watch('profile', () => source.stream);
      final first = old.first;
      source.add(17);
      expect(await first, 17);
      await cache.clear();
      expect(cancelled, isTrue);
      expect(await cache.watch('profile', () => Stream.value(99)).first, 99);
      await cache.clear();
      await source.close();
    },
  );
  test(
    'live cache propagates errors and recovers when source sends new data',
    () async {
      final cache = LiveStreamCache();
      final source = StreamController<int>();
      final stream = cache.watch('data', () => source.stream);
      final error = expectLater(stream.first, throwsStateError);
      source.addError(StateError('offline'));
      await error;
      source.add(3);
      await Future<void>.delayed(Duration.zero);
      expect(await stream.first, 3);
      await cache.clear();
      await source.close();
    },
  );
  test('retry reconnects after a failed source', () async {
    final cache = LiveStreamCache();
    await expectLater(
      cache
          .watch<int>('retry', () => Stream.error(StateError('offline')))
          .first,
      throwsStateError,
    );
    expect(await cache.watch<int>('retry', () => Stream.value(42)).first, 42);
    await cache.clear();
  });
  test(
    'assigned classes exclude unrelated records and handle multiple batches',
    () async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < 23; i++) {
        await db.collection('classes').doc('c$i').set({'name': 'Class $i'});
        await db
            .collection('users')
            .doc('trainer')
            .collection('classes')
            .doc('m$i')
            .set({'classId': 'c$i'});
      }
      await db.collection('classes').doc('unrelated').set({
        'name': 'Other class',
      });
      final iterator = StreamIterator(watchAssignedClasses(db, 'trainer'));
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.length, 23);
      expect(iterator.current.any((c) => c.id == 'unrelated'), isFalse);
      await db.collection('classes').doc('c0').update({'name': 'Updated'});
      do {
        expect(await iterator.moveNext(), isTrue);
      } while (!iterator.current.any((c) => c.data()['name'] == 'Updated'));
      await db
          .collection('users')
          .doc('trainer')
          .collection('classes')
          .doc('m0')
          .delete();
      do {
        expect(await iterator.moveNext(), isTrue);
      } while (iterator.current.any((c) => c.id == 'c0'));
      expect(iterator.current.length, 22);
      await iterator.cancel();
    },
  );
  test('empty memberships and missing class documents do not hang', () async {
    final db = FakeFirebaseFirestore();
    expect(await watchAssignedClasses(db, 'empty').first, isEmpty);
    await db
        .collection('users')
        .doc('missing')
        .collection('classes')
        .doc('absent')
        .set({});
    expect(await watchAssignedClasses(db, 'missing').first, isEmpty);
  });
  testWidgets(
    'unopened tabs perform no build work and visited state is retained',
    (tester) async {
      int first = 0, second = 0;
      Widget page(int index) => MaterialApp(
        home: Scaffold(
          body: LazyIndexedStack(
            index: index,
            children: [
              () {
                first++;
                return const TextField();
              },
              () {
                second++;
                return const Text('Second tab');
              },
            ],
          ),
        ),
      );
      await tester.pumpWidget(page(0));
      await tester.enterText(find.byType(TextField), 'kept');
      expect(second, 0);
      await tester.pumpWidget(page(1));
      expect(second, 1);
      await tester.pumpWidget(page(0));
      expect(find.text('kept'), findsOneWidget);
      expect(first, greaterThan(0));
    },
  );
  testWidgets(
    'requests survive rebuilds and refresh when tab or class changes',
    (tester) async {
      int calls = 0;
      Widget page(bool active, String id) => MaterialApp(
        home: RetainedFutureBuilder<int>(
          requestKey: id,
          active: active,
          load: () async => ++calls,
          builder: (context, snapshot) =>
              Text('value: ' + snapshot.data.toString()),
        ),
      );
      await tester.pumpWidget(page(true, 'a'));
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(page(true, 'a'));
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(page(false, 'a'));
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(page(true, 'a'));
      await tester.pump();
      expect(calls, 2);
      await tester.pumpWidget(page(true, 'b'));
      await tester.pump();
      expect(calls, 3);
    },
  );
}
