import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/feedback_eligibility.dart';

void main() {
  test('only recorded NC II qualified students can see feedback', () {
    expect(FeedbackEligibility.isQualified(null), isFalse);
    for (final value in [null, false, 'true', 1]) {
      expect(
        FeedbackEligibility.isQualified({
          'role': 'student',
          'nc2Passed': value,
        }),
        isFalse,
      );
    }
    expect(
      FeedbackEligibility.isQualified({'role': 'teacher', 'nc2Passed': true}),
      isFalse,
    );
    expect(
      FeedbackEligibility.isQualified({'role': 'student', 'nc2Passed': true}),
      isTrue,
    );
  });
  test('submission rechecks qualification when it changes', () async {
    final db = FakeFirebaseFirestore();
    final ref = db.collection('users').doc('student');
    await ref.set({'role': 'student', 'nc2Passed': true});
    await FeedbackEligibility.requireQualified(
      firestore: db,
      userId: 'student',
    );
    await ref.update({'nc2Passed': false});
    await expectLater(
      FeedbackEligibility.requireQualified(firestore: db, userId: 'student'),
      throwsStateError,
    );
  });
  test('missing student record is blocked', () async {
    await expectLater(
      FeedbackEligibility.requireQualified(
        firestore: FakeFirebaseFirestore(),
        userId: 'missing',
      ),
      throwsStateError,
    );
  });
}
