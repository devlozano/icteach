import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/registration_invitation_service.dart';

void main() {
  const lrn = '123456789012';
  late FakeFirebaseFirestore db;
  late RegistrationInvitationService service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = RegistrationInvitationService(firestore: db);
    await db.collection('lrn_master_list').doc(lrn).set({
      'firstName': 'Niña',
      'lastName': 'Dela Cruz',
      'isRegistered': false,
    });
  });
  test('official identity is copied and LRN is claimed once', () async {
    final identity = await service.validateLrn(lrn);
    await service.claim(
      uid: 'student1',
      lrn: lrn,
      profile: identity.profileFields,
    );
    final profile = await db.collection('users').doc('student1').get();
    expect(profile.data()!['name'], 'Niña Dela Cruz');
    expect(profile.data()!['role'], 'student');
    expect(
      (await db.collection('students').doc('student1').get()).exists,
      isTrue,
    );
    await expectLater(
      service.claim(uid: 'student2', lrn: lrn, profile: identity.profileFields),
      throwsFormatException,
    );
    expect(
      (await db.collection('users').doc('student2').get()).exists,
      isFalse,
    );
  });
  test('different name is rejected without claiming the LRN', () async {
    final identity = await service.validateLrn(lrn);
    await expectLater(
      service.claim(
        uid: 'student1',
        lrn: lrn,
        profile: {...identity.profileFields, 'firstName': 'Other'},
      ),
      throwsFormatException,
    );
    expect(
      (await db.collection('users').doc('student1').get()).exists,
      isFalse,
    );
    expect(
      (await db.collection('lrn_master_list').doc(lrn).get())
          .data()!['isRegistered'],
      isFalse,
    );
  });
  test('master list change after verification is rejected', () async {
    final identity = await service.validateLrn(lrn);
    await db.collection('lrn_master_list').doc(lrn).update({
      'lastName': 'Updated',
    });
    await expectLater(
      service.claim(uid: 'student1', lrn: lrn, profile: identity.profileFields),
      throwsFormatException,
    );
  });
  test('missing and incomplete records cannot register', () async {
    await expectLater(
      service.validateLrn('999999999999'),
      throwsFormatException,
    );
    await db.collection('lrn_master_list').doc(lrn).update({'firstName': ''});
    await expectLater(service.validateLrn(lrn), throwsFormatException);
  });
}
