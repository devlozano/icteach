import {after, before, beforeEach, test} from 'node:test';
import {readFileSync} from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-icteach-archive',
    firestore: {
      host: '127.0.0.1',
      port: 8188,
      rules: readFileSync(
          new URL('../../firestore.rules', import.meta.url),
          'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/principal'), {
      role: 'admin',
      isActive: true,
    });
    await setDoc(doc(db, 'school_year_archives/2026-2027'), {
      name: '2026-2027',
      classCount: 1,
    });
    await setDoc(
        doc(db, 'school_year_archives/2026-2027/classes/class-a'),
        {classId: 'class-a'},
    );
  });
});

after(async () => env.cleanup());

test('principal can read a year archive and its class index', async () => {
  const db = env.authenticatedContext('principal').firestore();
  await assertSucceeds(getDoc(doc(db, 'school_year_archives/2026-2027')));
  await assertSucceeds(getDoc(
      doc(db, 'school_year_archives/2026-2027/classes/class-a'),
  ));
});

test('students cannot read archived school-year indexes', async () => {
  const db = env.authenticatedContext('student').firestore();
  await assertFails(getDoc(doc(db, 'school_year_archives/2026-2027')));
});

test('clients cannot create or alter an archive', async () => {
  for (const uid of ['principal', 'student']) {
    const db = env.authenticatedContext(uid).firestore();
    await assertFails(setDoc(doc(db, 'school_year_archives/2027-2028'), {
      name: '2027-2028',
    }));
  }
});
