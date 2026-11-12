import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/principal_assignments.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PrincipalAssignments service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = PrincipalAssignments(firestore: db, principalId: 'principal');
    for (final entry in {
      'principal': 'admin',
      'teacher': 'teacher',
      'other': 'teacher',
      'trainer': 'trainer',
    }.entries) {
      await db.collection('users').doc(entry.key).set({
        'role': entry.value,
        'isActive': true,
        'name': entry.key,
        'email': '${entry.key}@school.test',
      });
    }
    await db.collection('system_settings').doc('academic_year').set({
      'activeSchoolYear': '2026-2027',
    });
  });
  StaffAssignmentDraft sections() {
    final draft = StaffAssignmentDraft();
    draft.sections.first.name = 'Computer System Servicing';
    draft.sections.first.section = 'Grade 11 A';
    return draft;
  }

  test(
    'principal creates teacher-owned sections with school year and blocks duplicates',
    () async {
      final draft = sections();
      draft.sections.add(
        SectionDraft()
          ..name = 'Computer System Servicing'
          ..section = 'Grade 11 B',
      );
      await service.save('teacher', 'teacher', draft);
      final docs = (await db.collection('classes').get()).docs;
      expect(docs, hasLength(2));
      expect(
        docs.every(
          (d) =>
              d.data()['teacherId'] == 'teacher' &&
              d.data()['createdBy'] == 'principal' &&
              d.data()['schoolYear'] == '2026-2027',
        ),
        isTrue,
      );
      expect(docs.every((d) => d.id.length <= 128), isTrue);
      await expectLater(
        service.save('teacher', 'teacher', draft),
        throwsStateError,
      );
      expect((await db.collection('classes').get()).docs, hasLength(2));
    },
  );
  test(
    'teacher cannot create own sections and inactive teacher cannot be assigned',
    () async {
      await expectLater(
        PrincipalAssignments(
          firestore: db,
          principalId: 'teacher',
        ).save('teacher', 'teacher', sections()),
        throwsStateError,
      );
      await db.collection('users').doc('teacher').update({'isActive': false});
      await expectLater(
        service.save('teacher', 'teacher', sections()),
        throwsStateError,
      );
      expect((await db.collection('classes').get()).docs, isEmpty);
    },
  );
  test(
    'trainer receives memberships only for selected teachers active classes',
    () async {
      await service.save('teacher', 'teacher', sections());
      final classroom = (await db.collection('classes').get()).docs.single;
      final draft = StaffAssignmentDraft()..teacherId = 'teacher';
      draft.classIds.add(classroom.id);
      await service.save('trainer', 'trainer', draft);
      expect((await classroom.reference.get()).data()!['trainerIds'], [
        'trainer',
      ]);
      final member = await db
          .collection('users')
          .doc('trainer')
          .collection('classes')
          .doc(classroom.id)
          .get();
      expect(member.data()!['teacherId'], 'teacher');
      expect(member.data()!['classId'], classroom.id);
      draft.teacherId = 'other';
      await expectLater(
        service.save('trainer', 'trainer', draft),
        throwsStateError,
      );
      draft.teacherId = 'teacher';
      await classroom.reference.update({'status': 'archived'});
      await expectLater(
        service.save('trainer', 'trainer', draft),
        throwsStateError,
      );
    },
  );
  test(
    'saving a trainer assignment removes classes no longer selected',
    () async {
      final first = sections();
      first.sections.add(
        SectionDraft()
          ..name = 'Networking'
          ..section = 'Grade 11 B',
      );
      await service.save('teacher', 'teacher', first);
      final classes = (await db.collection('classes').get()).docs;
      final initial = StaffAssignmentDraft()..teacherId = 'teacher';
      initial.classIds.addAll(classes.map((doc) => doc.id));
      await service.save('trainer', 'trainer', initial);

      final updated = StaffAssignmentDraft()..teacherId = 'teacher';
      updated.classIds.add(classes.first.id);
      await service.save('trainer', 'trainer', updated);

      expect((await classes.first.reference.get()).data()!['trainerIds'], [
        'trainer',
      ]);
      expect(
        (await classes.last.reference.get()).data()!['trainerIds'],
        isEmpty,
      );
      expect(
        (await db
                .collection('users')
                .doc('trainer')
                .collection('classes')
                .doc(classes.last.id)
                .get())
            .exists,
        isFalse,
      );
    },
  );
  test('no sections created without an active academic year', () async {
    await db.collection('system_settings').doc('academic_year').delete();
    await expectLater(
      service.save('teacher', 'teacher', sections()),
      throwsStateError,
    );
    expect((await db.collection('classes').get()).docs, isEmpty);
  });
}
