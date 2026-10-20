import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/invitation_enrollment_service.dart';

void main() {
  test(
    'invited student automatically receives dashboard class membership',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('student').set({
        'uid': 'student',
        'role': 'student',
        'email': 'student@gmail.com',
        'invitedClassId': 'class-a',
      });
      await db.collection('students').doc('student').set({
        'uid': 'student',
        'role': 'student',
        'email': 'student@gmail.com',
      });
      await db.collection('classes').doc('class-a').set({
        'name': 'Grade 10 - ICT',
        'teacherId': 'teacher',
        'teacherName': 'Teacher One',
        'status': 'active',
        'enrolledStudentIds': ['student'],
      });
      await db
          .collection('classes')
          .doc('class-a')
          .collection('students')
          .doc('student')
          .set({'uid': 'student', 'classId': 'class-a'});

      expect(
        await InvitationEnrollmentService.reconcile(
          firestore: db,
          uid: 'student',
          authEmail: 'STUDENT@gmail.com',
        ),
        true,
      );

      final membership = await db
          .collection('users')
          .doc('student')
          .collection('classes')
          .doc('class-a')
          .get();
      expect(membership.data()?['className'], 'Grade 10 - ICT');
      expect(membership.data()?['teacherName'], 'Teacher One');
      expect(
        (await db.collection('users').doc('student').get())
            .data()?['currentClassId'],
        'class-a',
      );
      expect(
        (await db.collection('students').doc('student').get())
            .data()?['currentClassId'],
        'class-a',
      );
    },
  );

  test('account without an invitation is left unchanged', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('student').set({
      'uid': 'student',
      'role': 'student',
      'email': 'student@gmail.com',
    });
    expect(
      await InvitationEnrollmentService.reconcile(
        firestore: db,
        uid: 'student',
        authEmail: 'student@gmail.com',
      ),
      false,
    );
  });

  test('different signed-in Gmail cannot claim the invitation', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('student').set({
      'uid': 'student',
      'role': 'student',
      'email': 'student@gmail.com',
      'invitedClassId': 'class-a',
    });
    expect(
      () => InvitationEnrollmentService.reconcile(
        firestore: db,
        uid: 'student',
        authEmail: 'other@gmail.com',
      ),
      throwsA(isA<InvitationEnrollmentException>()),
    );
  });
}
