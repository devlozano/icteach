import {after, before, beforeEach, test} from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc} from 'firebase/firestore';
let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-icteach-lrn', firestore: {
    host: '127.0.0.1', port: 8188, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'lrn_master_list/123456789012'), {firstName: 'Existing', isRegistered: false});
    await setDoc(doc(context.firestore(), 'lrn_folders/archive'), {name: 'Historical'});
  });
});
for (const role of ['admin', 'teacher', 'student']) {
  test(`${role} cannot create, change or delete retired LRN records`, async () => {
    const db = env.authenticatedContext(role, role === 'admin' ? {admin: true} : {}).firestore();
    for (const path of ['lrn_master_list/123456789012', 'lrn_folders/archive']) {
      await assertFails(updateDoc(doc(db, path), {name: 'Changed'}));
      await assertFails(deleteDoc(doc(db, path)));
    }
    await assertFails(setDoc(doc(db, 'lrn_master_list/000000000001'), {isRegistered: false}));
    await assertFails(setDoc(doc(db, 'lrn_folders/new'), {name: 'New'}));
  });
}
test('historical LRN data remains readable only by Admin', async () => {
  const admin = env.authenticatedContext('admin', {admin: true}).firestore();
  await assertSucceeds(getDoc(doc(admin, 'lrn_master_list/123456789012')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'lrn_master_list/123456789012')));
  await assertFails(getDoc(doc(env.authenticatedContext('student').firestore(), 'lrn_master_list/123456789012')));
});
