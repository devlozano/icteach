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
test('student can leave an archived class atomically', async () => {
  const db = dbFor('student');
  await assertSucceeds(join(db).commit());
  await env.withSecurityRulesDisabled(c =>
    updateDoc(doc(c.firestore(), 'classes/class'), {status: 'archived'}));

  await assertSucceeds(writeBatch(db)
    .update(doc(db, 'classes/class'), {enrolledStudentIds: arrayRemove('student')})
    .delete(doc(db, 'classes/class/students/student'))
    .delete(doc(db, 'users/student/classes/class')).commit());

  assert.deepEqual(
    (await getDoc(doc(db, 'classes/class'))).data().enrolledStudentIds,
    [],
  );
  assert.equal(
    (await getDoc(doc(db, 'users/student/classes/class'))).exists(),
    false,
  );
});
test('archived roster removal fails unless both membership documents are deleted', async () => {
  const db = dbFor('student');
  await assertSucceeds(join(db).commit());
  await env.withSecurityRulesDisabled(c =>
    updateDoc(doc(c.firestore(), 'classes/class'), {status: 'archived'}));

  await assertFails(updateDoc(doc(db, 'classes/class'), {
    enrolledStudentIds: arrayRemove('student'),
  }));
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
test('student cannot add themselves by changing only the public class roster', async () => {
  await assertFails(updateDoc(doc(dbFor('student'), 'classes/class'), {
    enrolledStudentIds: arrayUnion('student'), updatedAt: serverTimestamp(),
  }));
});
test('student cannot forge another user membership or nested progress', async () => {
  await assertFails(setDoc(doc(dbFor('student'), 'users/other/classes/class'), {
    classId: 'class', classCode: 'ABC123', status: 'active',
  }));
  await assertFails(setDoc(doc(dbFor('student'), 'users/other/module_progress/lesson'), {
    classId: 'class', completed: true,
  }));
  await assertFails(setDoc(doc(dbFor('student'), 'students/other/progress/lesson'), {
    completed: true,
  }));
});
test('quiz retry requires teacher feedback and one explicit authorization', async () => {
  await assertSucceeds(join(dbFor('student')).commit());
  const result = {quizId: 'quiz', classId: 'class', studentId: 'student', studentName: 'Student',
    score: 4, totalPoints: 10, userAnswers: [], timeSpent: 30, attemptNumber: 1, retryAllowed: false};
  await assertSucceeds(setDoc(doc(dbFor('student'), 'users/student/quiz_results/quiz'), result));
  await assertSucceeds(setDoc(doc(dbFor('student'), 'quiz_results/quiz_student'), result));
  await assertFails(updateDoc(doc(dbFor('student'), 'users/student/quiz_results/quiz'), {score: 10}));
  await assertFails(updateDoc(doc(dbFor('student'), 'quiz_results/quiz_student'), {score: 10}));
  await assertFails(setDoc(doc(dbFor('other'), 'quiz_results/quiz_student'), {...result, score: 10}));

  const approval = {retryAllowed: true, teacherFeedback: 'Review the missed concepts.',
    retryAllowedAt: serverTimestamp(), attemptNumber: 1};
  await assertSucceeds(updateDoc(doc(dbFor('teacher'), 'users/student/quiz_results/quiz'), approval));
  await assertSucceeds(updateDoc(doc(dbFor('teacher'), 'quiz_results/quiz_student'), approval));
  await assertFails(updateDoc(doc(dbFor('other'), 'quiz_results/quiz_student'), approval));

  const retry = {score: 8, totalPoints: 10, userAnswers: [], timeSpent: 25,
    completedAt: serverTimestamp(), retryAllowed: false, attemptNumber: 2};
  await assertSucceeds(updateDoc(doc(dbFor('student'), 'users/student/quiz_results/quiz'), retry));
  await assertSucceeds(updateDoc(doc(dbFor('student'), 'quiz_results/quiz_student'), retry));
  await assertFails(updateDoc(doc(dbFor('student'), 'quiz_results/quiz_student'), {
    ...retry, score: 10, attemptNumber: 3,
  }));
});
test('archived students keep read and practice access but cannot change graded or forum data', async () => {
  const db = dbFor('student');
  await assertSucceeds(join(db).commit());
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'classes/class'), {status: 'archived'}));

  for (const path of ['modules/lesson', 'quizzes/quiz', 'assignments/task', 'forum_posts/post']) {
    await assertSucceeds(getDoc(doc(db, `classes/class/${path}`)));
  }
  await assertFails(setDoc(doc(db, 'classes/class/forum_posts/new'), {title: 'No'}));
  await assertFails(updateDoc(doc(db, 'classes/class/forum_posts/post'), {likeCount: 1}));
  await assertFails(setDoc(doc(db, 'users/student/module_progress/lesson'), {
    classId: 'class', moduleId: 'lesson', studentId: 'student', completed: true,
  }));
  const result = {quizId: 'quiz', classId: 'class', studentId: 'student', score: 8, totalPoints: 10};
  await assertFails(setDoc(doc(db, 'users/student/quiz_results/quiz'), result));
  await assertFails(setDoc(doc(db, 'quiz_results/quiz_student'), result));
  await assertFails(setDoc(doc(db, 'submissions/task_student'), {
    classId: 'class', assignmentId: 'task', studentId: 'student', content: 'answer',
  }));
  await assertSucceeds(setDoc(doc(db, 'users/student/practice_progress/class_simulation_demo'), {
    classId: 'class', studentId: 'student', contentType: 'simulation', contentId: 'demo', mode: 'practice',
  }));
  await assertSucceeds(setDoc(doc(collection(db, 'activity_events')), {
    classId: 'class', studentId: 'student', contentId: 'demo', mode: 'practice', event: 'practice_completed',
  }));
});
test('assignment submissions are class-scoped for students and their teacher', async () => {
  const studentDb = dbFor('student');
  await assertSucceeds(join(studentDb).commit());
  const submission = {
    classId: 'class', assignmentId: 'task', studentId: 'student',
    content: 'A complete student response', score: 0, isGraded: false,
  };
  await assertSucceeds(setDoc(doc(studentDb, 'submissions/task_student'), submission));
  await assertSucceeds(getDoc(doc(studentDb, 'submissions/task_student')));
  await assertFails(getDoc(doc(dbFor('other'), 'submissions/task_student')));

  const teacherDb = dbFor('teacher');
  const scoped = query(
    collection(teacherDb, 'submissions'),
    where('classId', '==', 'class'),
    where('assignmentId', '==', 'task'),
  );
  assert.equal((await assertSucceeds(getDocs(scoped))).size, 1);
  await assertSucceeds(updateDoc(doc(teacherDb, 'submissions/task_student'), {
    score: 10, feedback: 'Complete', isGraded: true, gradedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(studentDb, 'submissions/task_student'), {score: 10}));
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
