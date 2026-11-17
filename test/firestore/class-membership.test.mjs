import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, collection, query, where, getDoc, getDocs, setDoc, updateDoc,
  writeBatch, arrayUnion, arrayRemove, serverTimestamp} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-icteach-memberships', firestore: {
    host: '127.0.0.1', port: 8188,
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
const dbFor = uid => env.authenticatedContext(uid, {email: `${uid}@example.test`}).firestore();
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [uid, role] of Object.entries({student: 'student', other: 'student', teacher: 'teacher', trainer: 'trainer', principal: 'admin'})) {
      await setDoc(doc(db, `users/${uid}`), {uid, role, email: `${uid}@example.test`, name: uid, isActive: true});
    }
    await setDoc(doc(db, 'students/student'), {uid: 'student', role: 'student'});
    await setDoc(doc(db, 'classes/class'), {name: 'CSS', classCode: 'ABC123', teacherId: 'teacher',
      trainerIds: ['trainer'], sectionCode: 'A', schoolYear: '2026-2027', createdBy: 'principal',
      status: 'active', enrolledStudentIds: []});
    for (const path of ['modules/lesson', 'quizzes/quiz', 'assignments/task', 'forum_posts/post']) {
      await setDoc(doc(db, `classes/class/${path}`), {title: 'Content'});
    }
  });
});
function join(db, {uid = 'student', code = 'ABC123', role = 'student', extra = {}} = {}) {
  return writeBatch(db)
    .set(doc(db, `classes/class/students/${uid}`), {uid, name: uid, email: `${uid}@example.test`, role,
      joinedAt: serverTimestamp(), status: 'active', ...extra})
    .update(doc(db, 'classes/class'), {enrolledStudentIds: arrayUnion(uid), updatedAt: serverTimestamp()})
    .set(doc(db, `users/${uid}/classes/class`), {classId: 'class', classCode: code, teacherId: 'teacher', status: 'active'})
    .update(doc(db, `users/${uid}`), {currentClassId: 'class', updatedAt: serverTimestamp()});
}
test('code/QR lookup and complete atomic enrollment succeed', async () => {
  const db = dbFor('student');
  assert.equal((await assertSucceeds(getDocs(query(collection(db, 'classes'), where('classCode', '==', 'ABC123'), where('status', '==', 'active'))))).size, 1);
  const batch = join(db);
  batch.update(doc(db, 'students/student'), {currentClassId: 'class', updatedAt: serverTimestamp()});
  await assertSucceeds(batch.commit());
  for (const path of ['students/student', 'modules/lesson', 'quizzes/quiz', 'assignments/task', 'forum_posts/post']) {
    await assertSucceeds(getDoc(doc(db, `classes/class/${path}`)));
  }
  await assertSucceeds(setDoc(doc(db, 'classes/class/module_access/lesson_student'), {studentId: 'student', moduleId: 'lesson'}));
});
test('student leaves atomically and loses private class access', async () => {
  const db = dbFor('student');
  await assertSucceeds(join(db).commit());
  await assertSucceeds(writeBatch(db)
    .update(doc(db, 'classes/class'), {enrolledStudentIds: arrayRemove('student')})
    .delete(doc(db, 'classes/class/students/student'))
    .delete(doc(db, 'users/student/classes/class')).commit());
  assert.equal((await getDoc(doc(db, 'users/student'))).exists(), true);
  assert.equal((await getDoc(doc(db, 'users/student/classes/class'))).exists(), false);
  await assertFails(getDoc(doc(db, 'classes/class/modules/lesson')));
  await assertSucceeds(join(db).commit());
});
for (const options of [{code: 'WRONG'}, {uid: 'other'}, {role: 'teacher'}, {extra: {score: 100}}]) {
  test(`invalid join is rejected atomically: ${JSON.stringify(options)}`, async () => {
    await assertFails(join(dbFor('student'), options).commit());
    assert.deepEqual((await getDoc(doc(dbFor('student'), 'classes/class'))).data().enrolledStudentIds, []);
    assert.equal((await getDoc(doc(dbFor('student'), 'users/student/classes/class'))).exists(), false);
  });
}
test('inactive accounts, unprovisioned accounts and archived classes cannot join', async () => {
  await assertFails(join(dbFor('missing'), {uid: 'missing'}).commit());
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'users/student'), {isActive: false}));
  await assertFails(join(dbFor('student')).commit());
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(), 'users/student'), {isActive: true});
    await updateDoc(doc(c.firestore(), 'classes/class'), {status: 'archived'});
  });
  await assertFails(join(dbFor('student')).commit());
});
test('student cannot write roster without final enrollment and matching membership', async () => {
  await assertFails(setDoc(doc(dbFor('student'), 'classes/class/students/student'), {
    uid: 'student', name: 'student', email: 'student@example.test', role: 'student', status: 'active', joinedAt: serverTimestamp(),
  }));
});
test('teacher/trainer content management and principal read-only content remain supported', async () => {
  for (const uid of ['teacher', 'trainer']) {
    for (const type of ['modules', 'quizzes', 'assignments']) {
      await assertSucceeds(setDoc(doc(dbFor(uid), `classes/class/${type}/new`), {title: uid}));
    }
  }
  await assertSucceeds(getDoc(doc(dbFor('principal'), 'classes/class/modules/new')));
  await assertFails(setDoc(doc(dbFor('principal'), 'classes/class/modules/new'), {title: 'Denied'}));
  await assertFails(getDoc(doc(dbFor('other'), 'classes/class/forum_posts/post')));
});
