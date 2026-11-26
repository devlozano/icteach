import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, serverTimestamp, writeBatch, arrayUnion, arrayRemove} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-icteach-student-invitations',
    firestore: {
      host: '127.0.0.1',
      port: 8188,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/teacher'), {role: 'teacher', isActive: true});
    await setDoc(doc(db, 'users/other'), {role: 'teacher', isActive: true});
    await setDoc(doc(db, 'classes/class-a'), {
      teacherId: 'teacher',
      teacherName: 'Teacher One',
      name: 'CSS 10',
      classCode: 'CSS101',
      status: 'active',
      enrolledStudentIds: [],
    });
  });
});

const teacherDb = (uid = 'teacher') => env.authenticatedContext(uid, {
  email: `${uid}@example.test`,
}).firestore();

function removalBatch(db) {
  return writeBatch(db)
    .delete(doc(db, 'classes/class-a/students/student'))
    .delete(doc(db, 'users/student/classes/class-a'))
    .update(doc(db, 'classes/class-a'), {enrolledStudentIds: arrayRemove('student')});
}

for (const profile of [null, {}, {role: 'student'}]) {
  test(`assigned teacher removes roster membership with profile ${JSON.stringify(profile)}`, async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      if (profile !== null) await setDoc(doc(db, 'users/student'), profile);
      await updateDoc(doc(db, 'classes/class-a'), {enrolledStudentIds: ['student']});
      await setDoc(doc(db, 'classes/class-a/students/student'), {uid: 'student'});
      await setDoc(doc(db, 'users/student/classes/class-a'), {classId: 'class-a'});
      await setDoc(doc(db, 'users/student/classes/class-b'), {classId: 'class-b'});
    });
    await assertFails(removalBatch(teacherDb('other')).commit());
    await assertSucceeds(removalBatch(teacherDb()).commit());
    const db = teacherDb();
    assert.deepEqual((await getDoc(doc(db, 'classes/class-a'))).data().enrolledStudentIds, []);
    assert.equal((await getDoc(doc(db, 'users/student/classes/class-a'))).exists(), false);
    assert.equal((await getDoc(doc(db, 'users/student/classes/class-b'))).exists(), true);
    assert.deepEqual((await getDoc(doc(db, 'users/student'))).data(), profile ?? undefined);
  });
}

function invitationBatch(db, overrides = {}) {
  const profile = invitedProfile(overrides);
  return writeBatch(db)
    .set(doc(db, 'users/student'), profile)
    .set(doc(db, 'students/student'), profile)
    .set(doc(db, 'classes/class-a/students/student'), {...profile, classId: 'class-a', notificationSent: false})
    .set(doc(db, 'users/student/classes/class-a'), {classId: 'class-a', teacherId: 'teacher', status: 'active', joinedAt: serverTimestamp()})
    .update(doc(db, 'classes/class-a'), {enrolledStudentIds: arrayUnion('student')});
}

test('removal cannot delete accounts or leave an enrolled student with a missing membership', async () => {
  const db = teacherDb();
  await assertSucceeds(invitationBatch(db).commit());
  await assertFails(writeBatch(db).delete(doc(db, 'users/student/classes/class-a')).commit());
  await assertFails(writeBatch(db).delete(doc(db, 'users/student')).commit());
  await assertFails(writeBatch(db).delete(doc(db, 'students/student')).commit());
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users/teacher'), {isActive: false});
  });
  await assertFails(removalBatch(db).commit());
});

test('new student profile and class membership commit atomically', async () => {
  const db = teacherDb();
  await assertSucceeds(invitationBatch(db).commit());
  assert.deepEqual((await getDoc(doc(db, 'classes/class-a'))).data().enrolledStudentIds, ['student']);
  const student = teacherDb('student');
  await assertSucceeds(getDoc(doc(student, 'users/student/classes/class-a')));
  await assertSucceeds(getDoc(doc(student, 'classes/class-a/students/student')));
  await assertSucceeds(updateDoc(doc(db, 'classes/class-a/students/student'), {
    invitationStatus: 'sent', notificationSent: true, notifiedAt: serverTimestamp(),
  }));
});

test('atomic invitation rejects another teacher and does not create partial records', async () => {
  await assertFails(invitationBatch(teacherDb('other'), {invitedBy: 'other'}).commit());
  assert.equal((await getDoc(doc(teacherDb(), 'users/student'))).exists(), false);
});

test('atomic invitation cannot promote the new student to staff', async () => {
  await assertFails(invitationBatch(teacherDb(), {role: 'teacher'}).commit());
});

test('membership cannot be created without a student profile', async () => {
  const db = teacherDb();
  await assertFails(writeBatch(db)
    .set(doc(db, 'users/missing/classes/class-a'), {classId: 'class-a'})
    .update(doc(db, 'classes/class-a'), {enrolledStudentIds: arrayUnion('missing')}).commit());
});

function invitedProfile(overrides = {}) {
  return {
    uid: 'student',
    email: 'student@example.test',
    role: 'student',
    firstName: 'Test',
    middleName: '',
    lastName: 'Student',
    extension: '',
    name: 'Test Student',
    displayName: 'Test Student',
    invitationStatus: 'pending',
    invitedAt: serverTimestamp(),
    invitedBy: 'teacher',
    invitedClassId: 'class-a',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

test('assigned active teacher can create a constrained student profile', async () => {
  const db = teacherDb();
  await assertSucceeds(setDoc(doc(db, 'users/student'), invitedProfile()));
  await assertSucceeds(setDoc(doc(db, 'students/student'), invitedProfile()));
  assert.equal((await getDoc(doc(db, 'users/student'))).data().role, 'student');
});

test('admin can manage staff but cannot create or convert student profiles', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/admin'), {role: 'admin'});
    await setDoc(doc(context.firestore(), 'classes/admin-class'), {teacherId: 'admin'});
    await setDoc(doc(context.firestore(), 'users/existing'), {uid: 'existing', role: 'trainer'});
  });
  const db = teacherDb('admin');
  await assertSucceeds(setDoc(doc(db, 'users/staff'), {role: 'teacher', uid: 'staff'}));
  for (const collection of ['users', 'students']) {
    await assertFails(setDoc(doc(db, `${collection}/student`), invitedProfile({invitedBy: 'admin', invitedClassId: 'admin-class'})));
  }
  await assertFails(setDoc(doc(db, 'students/staff'), {role: 'teacher', uid: 'staff'}));
  await assertFails(updateDoc(doc(db, 'users/existing'), {role: 'student'}));
  await assertSucceeds(updateDoc(doc(db, 'users/existing'), {isActive: false}));
});

test('another teacher cannot create a profile for a class they do not own', async () => {
  await assertFails(setDoc(
    doc(teacherDb('other'), 'users/student'),
    invitedProfile({invitedBy: 'other'}),
  ));
});

for (const overrides of [
  {role: 'admin'},
  {uid: 'victim'},
  {invitedBy: 'other'},
  {invitedClassId: 'missing'},
  {email: 'invalid'},
  {firstName: ''},
  {firstName: 'x'.repeat(81)},
  {middleName: 'x'.repeat(81)},
  {lastName: ''},
  {extension: 'x'.repeat(31)},
  {invitationStatus: 'sent'},
  {extra: true},
]) {
  test(`rejects forged invitation field ${Object.keys(overrides)[0]}`, async () => {
    await assertFails(setDoc(doc(teacherDb(), 'users/student'), invitedProfile(overrides)));
  });
}

test('inactive teacher cannot create student profiles', async () => {
  await env.withSecurityRulesDisabled((context) => updateDoc(
    doc(context.firestore(), 'users/teacher'),
    {isActive: false},
  ));
  await assertFails(setDoc(doc(teacherDb(), 'users/student'), invitedProfile()));
});

test('student cannot change protected invitation identity after creation', async () => {
  await assertSucceeds(setDoc(doc(teacherDb(), 'users/student'), invitedProfile()));
  const student = teacherDb('student');
  await assertFails(updateDoc(doc(student, 'users/student'), {role: 'admin'}));
  await assertFails(updateDoc(doc(student, 'users/student'), {firstName: 'Changed'}));
  await assertFails(updateDoc(doc(student, 'users/student'), {invitedClassId: 'other'}));
  await assertFails(updateDoc(doc(student, 'users/student'), {invitedBy: 'attacker'}));
});

const repairId = 'a'.repeat(64);
const repairData = () => ({
  email: 'student@example.test',
  firstName: 'Ana',
  middleName: '',
  lastName: 'Santos',
  extension: '',
  name: 'Ana Santos',
  classId: 'class-a',
  className: 'CSS 10',
  teacherId: 'teacher',
  teacherName: 'Teacher One',
  schoolYear: '2026-2027',
  status: 'pending',
  notificationSent: false,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

test('orphan Auth account can claim only its own teacher-issued repair', async () => {
  await assertSucceeds(setDoc(
    doc(teacherDb(), `student_account_repairs/${repairId}`),
    repairData(),
  ));
  await assertFails(getDoc(doc(
    teacherDb('other'),
    `student_account_repairs/${repairId}`,
  )));

  const student = teacherDb('student');
  await assertSucceeds(getDoc(doc(
    student,
    `student_account_repairs/${repairId}`,
  )));
  const profile = {
    uid: 'student', email: 'student@example.test', role: 'student',
    firstName: 'Ana', middleName: '', lastName: 'Santos', extension: '',
    name: 'Ana Santos', displayName: 'Ana Santos', invitationStatus: 'sent',
    invitedAt: serverTimestamp(), invitedBy: 'teacher', invitedClassId: 'class-a',
    accountRepairId: repairId, currentClassId: 'class-a', currentClassName: 'CSS 10',
    currentTeacherName: 'Teacher One', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  await assertSucceeds(writeBatch(student)
    .set(doc(student, 'users/student'), profile)
    .set(doc(student, 'students/student'), profile)
    .commit());
  await assertSucceeds(updateDoc(
    doc(student, `student_account_repairs/${repairId}`),
    {
      status: 'claimed', claimedUid: 'student', claimedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  ));
  await assertSucceeds(writeBatch(student)
    .set(doc(student, 'users/student/classes/class-a'), {
      classId: 'class-a', className: 'CSS 10', description: '', sectionCode: '',
      classCode: 'CSS101', teacherId: 'teacher', teacherName: 'Teacher One',
      teacherEmail: '', schoolYear: '', joinedAt: serverTimestamp(), status: 'active',
    })
    .set(doc(student, 'classes/class-a/students/student'), {
      uid: 'student', name: 'Ana Santos', email: 'student@example.test',
      role: 'student', joinedAt: serverTimestamp(), status: 'active',
    })
    .update(doc(student, 'classes/class-a'), {
      enrolledStudentIds: arrayUnion('student'), updatedAt: serverTimestamp(),
    })
    .commit());
});
