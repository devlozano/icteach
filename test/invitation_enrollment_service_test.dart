import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/invitation_enrollment_service.dart';
import 'package:icteach/services/student_account_repair.dart';

void main() {
  test(
    'existing Auth account claims its pending repair and joins the class',
    () async {
      final db = FakeFirebaseFirestore();
      final repairId = studentAccountRepairId('student@example.test');
      await db.collection('student_account_repairs').doc(repairId).set({
        'email': 'student@example.test',
        'firstName': 'Ana',
        'middleName': 'M',
        'lastName': 'Santos',
        'extension': '',
        'name': 'Ana M Santos',
        'classId': 'class-a',
        'teacherId': 'teacher',
        'status': 'pending',
      });
      await db.collection('classes').doc('class-a').set({
        'name': 'CSS 10',
        'teacherId': 'teacher',
        'teacherName': 'Teacher One',
        'classCode': 'CSS101',
        'status': 'active',
        'enrolledStudentIds': <String>[],
      });

      expect(
        await InvitationEnrollmentService.reconcile(
          firestore: db,
          uid: 'auth-uid',
          authEmail: 'STUDENT@example.test',
        ),
        true,
      );
      expect(
        (await db.collection('users').doc('auth-uid').get()).data()?['role'],
        'student',
      );
      expect(
        (await db.collection('classes').doc('class-a').get())
            .data()?['enrolledStudentIds'],
        contains('auth-uid'),
      );
      expect(
        (await db.collection('student_account_repairs').doc(repairId).get())
            .data()?['status'],
        'claimed',
      );
    },
  );

  test('removed student does not regain class membership on sign in', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('student').set({
      'role': 'student',
      'email': 'student@gmail.com',
      'invitedClassId': 'old-class',
    });
    await db.collection('classes').doc('old-class').set({
      'status': 'active',
      'enrolledStudentIds': <String>[],
    });
    expect(
      await InvitationEnrollmentService.reconcile(
        firestore: db,
        uid: 'student',
        authEmail: 'student@gmail.com',
      ),
      false,
    );
    expect(
      (await db.collection('users').doc('student').collection('classes').get())
          .docs,
      isEmpty,
    );
  });
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
