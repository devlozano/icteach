import {after, before, beforeEach, test} from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, updateDoc, serverTimestamp} from 'firebase/firestore';
let env;
const path = 'css_gradebooks/teacher/classes/class';
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-icteach-css', firestore: {
    host: '127.0.0.1', port: 8188,
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'users/teacher'), {role:'teacher',isActive:true});
    await setDoc(doc(ctx.firestore(), 'users/other'), {role:'teacher',isActive:true});
    await setDoc(doc(ctx.firestore(), 'users/student'), {role:'student',isActive:true});
    await setDoc(doc(ctx.firestore(), 'classes/class'), {teacherId:'teacher',enrolledStudentIds:['student']});
    await setDoc(doc(ctx.firestore(), path), {profile:'techPro',year:2026});
  });
});
const db = uid => env.authenticatedContext(uid).firestore();
const record = (overrides={}) => ({studentId:'student',term:1,
  scores:{ww:{raw:0,maximum:100}},updatedAt:serverTimestamp(),...overrides});
test('owner can save draft, read, and update valid scores', async () => {
  const ref = doc(db('teacher'), path+'/records/student_1');
  await assertSucceeds(setDoc(ref, record()));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(updateDoc(ref, {scores:{},updatedAt:serverTimestamp()}));
});
test('new gradebook accepts TechPro only and rejects wrong year and ownership', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(),'classes/new-class'),{teacherId:'teacher',enrolledStudentIds:['student']});
  });
  const ref = doc(db('teacher'),'css_gradebooks/teacher/classes/new-class');
  await assertFails(setDoc(ref,{profile:'tle',year:2026,updatedAt:serverTimestamp()}));
  await assertFails(setDoc(ref,{profile:'techPro',year:2025,updatedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db('other'),'css_gradebooks/other/classes/new-class'),
    {profile:'techPro',year:2026,updatedAt:serverTimestamp()}));
  await assertSucceeds(setDoc(ref,{profile:'techPro',year:2026,updatedAt:serverTimestamp()}));
});
test('student, other teacher, and unauthenticated access cannot bypass namespace', async () => {
  for (const client of [db('student'),db('other'),env.unauthenticatedContext().firestore()]) {
    await assertFails(setDoc(doc(client,path+'/records/student_1'),record()));
    await assertFails(getDoc(doc(client,path)));
  }
});
test('invalid scores, term four, outsider, and unknown fields rejected on create and update', async () => {
  const ref = doc(db('teacher'),path+'/records/student_1');
  for (const patch of [{term:4},{studentId:'outsider'},{extra:true},
    {scores:{ww:{raw:101,maximum:100}}},{scores:{ww:{raw:0,maximum:0}}},
    {scores:{ww:{raw:'5',maximum:100}}},{scores:{attendance:{raw:1,maximum:1}}}]) {
    await assertFails(setDoc(ref,record(patch)));
  }
  await assertSucceeds(setDoc(ref,record()));
  await assertFails(updateDoc(ref,{scores:{pt:{raw:-1,maximum:100}},updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db('teacher'),path),{profile:'techPro'}));
});
