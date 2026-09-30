import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp} from 'firebase/firestore';
let env;
const lrn = '123456789012';
const master = {firstName: 'Test', lastName: 'Student', middleName: '', isRegistered: false};
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-icteach-lrn', firestore: {
    host: '127.0.0.1', port: 8188, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), 'lrn_master_list', lrn), master));
});
const admin = () => env.authenticatedContext('admin', {admin: true}).firestore();
const student = () => env.authenticatedContext('student').firestore();
test('only trusted admin claims can list, create folders, move or delete LRNs', async () => {
  const db = student();
  await setDoc(doc(db, 'users/student'), {role: 'admin'});
  await assertFails(getDocs(collection(db, 'lrn_master_list')));
  await assertFails(setDoc(doc(db, 'lrn_folders/a'), {name: 'A', kind: 'class', createdAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(db, 'lrn_master_list', lrn), {folderId: ''}));
  await assertFails(deleteDoc(doc(db, 'lrn_master_list', lrn)));
  await assertSucceeds(getDocs(collection(admin(), 'lrn_master_list')));
  await assertSucceeds(deleteDoc(doc(admin(), 'lrn_master_list', lrn)));
});
test('folders persist and validate names; moves preserve registration fields', async () => {
  const db = admin();
  await assertSucceeds(setDoc(doc(db, 'lrn_folders/a'), {name: 'Grade 12', kind: 'class', createdAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(db, 'lrn_folders/a'), {name: ''}));
  await assertFails(updateDoc(doc(db, 'lrn_folders/a'), {name: 'x'.repeat(81)}));
  await assertFails(updateDoc(doc(db, 'lrn_folders/a'), {kind: 'other'}));
  await assertSucceeds(updateDoc(doc(db, 'lrn_master_list', lrn), {folderId: 'a'}));
  await assertFails(updateDoc(doc(db, 'lrn_master_list', lrn), {folderId: 'missing'}));
  await assertFails(updateDoc(doc(db, 'lrn_master_list', lrn), {registeredUid: 'other'}));
  await assertSucceeds(updateDoc(doc(db, 'lrn_master_list', lrn), {folderId: ''}));
});
test('only a trusted admin can delete a batch or class folder', async () => {
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), 'lrn_folders/a'), {
    name: 'Batch 2026', kind: 'batch', createdAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(student(), 'lrn_folders/a')));
  await assertSucceeds(deleteDoc(doc(admin(), 'lrn_folders/a')));
});
test('imports require admin and validate destination', async () => {
  const data = {...master, uploadedAt: serverTimestamp(), folderId: ''};
  await assertFails(setDoc(doc(student(), 'lrn_master_list/000000000001'), data));
  await assertSucceeds(setDoc(doc(admin(), 'lrn_master_list/000000000001'), data));
  await assertFails(setDoc(doc(admin(), 'lrn_master_list/000000000002'), {...data, folderId: 'missing'}));
});
function claim(db) {
  const batch = writeBatch(db);
  const profile = {uid: 'student', role: 'student', lrn, firstName: 'Test', lastName: 'Student', middleName: ''};
  batch.set(doc(db, 'users/student'), profile);
  batch.set(doc(db, 'students/student'), profile);
  batch.update(doc(db, 'lrn_master_list', lrn), {isRegistered: true, registeredUid: 'student', registeredAt: serverTimestamp()});
  return batch.commit();
}
test('registration stays atomic and registered deletion retains the claim', async () => {
  const db = student();
  await assertSucceeds(claim(db));
  await assertFails(deleteDoc(doc(admin(), 'lrn_master_list', lrn)));
  await assertSucceeds(updateDoc(doc(admin(), 'lrn_master_list', lrn), {archived: true}));
  const data = (await getDoc(doc(admin(), 'lrn_master_list', lrn))).data();
  assert.equal(data.registeredUid, 'student');
  assert.equal(data.isRegistered, true);
  await assertFails(updateDoc(doc(admin(), 'lrn_master_list', lrn), {isRegistered: false}));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'lrn_master_list', lrn)));
});
test('exact pre-account lookup works and deleted pending LRN cannot be claimed', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(db, 'lrn_master_list', lrn)));
  await assertFails(getDocs(collection(db, 'lrn_master_list')));
  await deleteDoc(doc(admin(), 'lrn_master_list', lrn));
  await assertFails(claim(student()));
});
test('student cannot archive a record or claim without matching profiles', async () => {
  await assertFails(updateDoc(doc(student(), 'lrn_master_list', lrn), {archived: true}));
  await assertFails(updateDoc(doc(student(), 'lrn_master_list', lrn), {isRegistered: true, registeredUid: 'student', registeredAt: serverTimestamp()}));
});
