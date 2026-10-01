import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/learning_path_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('classes').doc('c').set({
      'teacherId': 'teacher',
      'enrolledStudentIds': ['student'],
      'status': 'active',
    });
    await db.collection('classes').doc('c').collection('quizzes').doc('q').set({
      'isPublished': true,
      'questions': [
        {'text': 'Question'},
      ],
    });
  });
  Future<void> open({String student = 'student'}) =>
      LearningPathService.requireQuizAvailable(
        'c',
        'q',
        firestore: db,
        studentId: student,
      );
  test('quiz practice entry is rejected', () async {
    await expectLater(
      LearningPathService.requirePrepared('c', 'quiz', 'q', practice: true),
      throwsStateError,
    );
  });
  test('published quiz opens with no lesson link or practice record', () async {
    await open();
  });
  test('current saved result completes simulation Part A', () async {
    await db
        .collection('users')
        .doc('student')
        .collection('quiz_results')
        .doc('q')
        .set({'quizId': 'q', 'classId': 'c'});

    expect(
      await LearningPathService.hasCompletedQuiz(
        'c',
        'q',
        firestore: db,
        studentId: 'student',
      ),
      isTrue,
    );
  });
  test('legacy result without classId completes simulation Part A', () async {
    await db
        .collection('users')
        .doc('student')
        .collection('quiz_results')
        .doc('q')
        .set({'quizId': 'q'});

    expect(
      await LearningPathService.hasCompletedQuiz(
        'c',
        'q',
        firestore: db,
        studentId: 'student',
      ),
      isTrue,
    );
  });
  test(
    'shared saved result is used when the personal copy is missing',
    () async {
      await db.collection('quiz_results').doc('q_student').set({
        'quizId': 'q',
        'classId': 'c',
        'studentId': 'student',
      });

      expect(
        await LearningPathService.hasCompletedQuiz(
          'c',
          'q',
          firestore: db,
          studentId: 'student',
        ),
        isTrue,
      );
    },
  );
  test(
    'result from another class does not complete simulation Part A',
    () async {
      await db
          .collection('users')
          .doc('student')
          .collection('quiz_results')
          .doc('q')
          .set({'quizId': 'q', 'classId': 'other-class'});

      expect(
        await LearningPathService.hasCompletedQuiz(
          'c',
          'q',
          firestore: db,
          studentId: 'student',
        ),
        isFalse,
      );
    },
  );
  test(
    'obsolete lesson link and module lock cannot strand a published quiz',
    () async {
      await db
          .collection('classes')
          .doc('c')
          .collection('learning_paths')
          .doc('quiz_q')
          .set({'moduleId': 'deleted-lesson'});
      await db.collection('content_locks').add({
        'classId': 'c',
        'contentType': 'module',
        'contentId': '*',
        'isLocked': true,
      });
      await open();
    },
  );
  test(
    'unpublishing after opening blocks the submission access check',
    () async {
      await open();
      await db
          .collection('classes')
          .doc('c')
          .collection('quizzes')
          .doc('q')
          .update({'isPublished': false});
      await expectLater(open(), throwsStateError);
    },
  );
  test('empty quiz is blocked', () async {
    await db
        .collection('classes')
        .doc('c')
        .collection('quizzes')
        .doc('q')
        .update({'questions': []});
    await expectLater(open(), throwsStateError);
  });
  test('unenrolled student is blocked', () async {
    await expectLater(open(student: 'outsider'), throwsStateError);
  });
  test('archived class is blocked', () async {
    await db.collection('classes').doc('c').update({'status': 'archived'});
    await expectLater(open(), throwsStateError);
  });
  for (final type in ['quiz', 'practice']) {
    for (final target in ['q', '*']) {
      test(
        '$type lock $target blocks and teacher unlock restores access',
        () async {
          final ref = await db.collection('content_locks').add({
            'classId': 'c',
            'contentType': type,
            'contentId': target,
            'isLocked': true,
          });
          await expectLater(open(), throwsStateError);
          await ref.update({'isLocked': false});
          await open();
        },
      );
    }
  }
}
