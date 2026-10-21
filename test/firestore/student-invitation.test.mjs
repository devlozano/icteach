import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, serverTimestamp} from 'firebase/firestore';

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
      enrolledStudentIds: [],
    });
  });
});

const teacherDb = (uid = 'teacher') => env.authenticatedContext(uid, {
  email: `${uid}@example.test`,
}).firestore();

function invitedProfile(overrides = {}) {
  return {
    uid: 'student',
    email: 'student@example.test',
    role: 'student',
    firstName: 'Test',
    lastName: 'Student',
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
  {firstName: 'x'.repeat(81)},
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
