import {after, before, beforeEach, test} from 'node:test';
import {readFileSync} from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';

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
    await setDoc(doc(db, 'classes/legacy-class'), {
      name: 'Legacy CSS',
      schoolYear: '2026-2027',
      status: 'active',
    });
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

test('principal can create a strictly validated archive index', async () => {
  const db = env.authenticatedContext('principal').firestore();
  await assertSucceeds(setDoc(doc(db, 'school_year_archives/2027-2028'), {
    name: '2027-2028',
    schoolYear: '2027-2028',
    status: 'archived',
    classCount: 1,
    dataLocation: 'classes and their nested subcollections',
    dataPreservedInSource: true,
    updatedAt: new Date(),
  }));
  await assertSucceeds(setDoc(
      doc(db, 'school_year_archives/2027-2028/classes/class-b'),
      {
        classId: 'class-b',
        className: 'CSS 11',
        sectionCode: 'A',
        teacherId: 'teacher-a',
        teacherName: 'Teacher A',
        schoolYear: '2027-2028',
        sourcePath: 'classes/class-b',
        archivedAt: new Date(),
        dataPreservedInSource: true,
      },
  ));
});

test('students and malformed principal writes cannot alter archives', async () => {
  const student = env.authenticatedContext('student').firestore();
  const principal = env.authenticatedContext('principal').firestore();
  await assertFails(setDoc(doc(student, 'school_year_archives/2027-2028'), {
    name: '2027-2028',
  }));
  await assertFails(setDoc(doc(principal, 'school_year_archives/2027-2028'), {
    name: '2027-2028',
    status: 'active',
  }));
});

test('principal can archive a legacy class without rewriting its schema', async () => {
  const db = env.authenticatedContext('principal').firestore();
  await assertSucceeds(updateDoc(doc(db, 'classes/legacy-class'), {
    status: 'archived',
    archivedAt: new Date(),
    archiveSchoolYear: '2026-2027',
    archiveReason: 'School year advanced to 2027-2028',
  }));
});
