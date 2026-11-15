'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  makeArchiveSchoolYearHandler,
  parseSchoolYear,
  schoolYearForDate,
} = require('../archive-school-year');

class FakeDocumentReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
    this.id = path.split('/').at(-1);
  }
  async get() {
    const value = this.store.get(this.path);
    return {exists: value !== undefined, data: () => value};
  }
  async set(value, options) {
    const previous = this.store.get(this.path) || {};
    this.store.set(this.path, options?.merge ? {...previous, ...value} : value);
  }
  collection(name) {
    return new FakeCollectionReference(this.store, `${this.path}/${name}`);
  }
}

class FakeCollectionReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
  }
  doc(id) {
    return new FakeDocumentReference(this.store, `${this.path}/${id}`);
  }
  async get() {
    const prefix = `${this.path}/`;
    const docs = [...this.store.entries()]
        .filter(([path]) => path.startsWith(prefix) &&
          !path.slice(prefix.length).includes('/'))
        .map(([path, value]) => ({
          id: path.slice(prefix.length),
          ref: new FakeDocumentReference(this.store, path),
          data: () => value,
        }));
    return {docs};
  }
}

class FakeFirestore {
  constructor(entries) {
    this.store = new Map(entries);
  }
  collection(name) {
    return new FakeCollectionReference(this.store, name);
  }
  batch() {
    const operations = [];
    return {
      update: (ref, value) => operations.push(() => ref.set(value, {merge: true})),
      set: (ref, value, options) =>
        operations.push(() => ref.set(value, options)),
      commit: async () => Promise.all(operations.map((operation) => operation())),
    };
  }
}

test('accepts only consecutive school-year names', () => {
  assert.deepEqual(parseSchoolYear('2026-2027'), {
    name: '2026-2027',
    startYear: 2026,
    endYear: 2027,
  });
  assert.equal(parseSchoolYear('2026-2028'), null);
  assert.equal(parseSchoolYear('School Year 2026'), null);
});

test('uses June 1 as the Philippine school-year rollover', () => {
  assert.equal(
      schoolYearForDate(new Date('2027-05-31T15:59:59.000Z')).name,
      '2026-2027',
  );
  assert.equal(
      schoolYearForDate(new Date('2027-05-31T16:00:00.000Z')).name,
      '2027-2028',
  );
});

test('does not depend on the server machine timezone', () => {
  const date = new Date('2031-12-15T08:00:00.000Z');
  assert.equal(schoolYearForDate(date, 'Asia/Manila').name, '2031-2032');
  assert.equal(schoolYearForDate(date, 'America/Los_Angeles').name,
      '2031-2032');
});

test('archives expired classes under their year without moving their data', async () => {
  const nestedData = {lesson: 'preserved'};
  const db = new FakeFirestore([
    ['system_settings/academic_year', {activeSchoolYear: '2026-2027'}],
    ['classes/old-class', {
      name: 'CSS 11', schoolYear: '2026-2027', status: 'active',
    }],
    ['classes/old-class/modules/module-a', nestedData],
    ['classes/current-class', {
      name: 'CSS 12', schoolYear: '2027-2028', status: 'active',
    }],
  ]);
  const fieldValue = {serverTimestamp: () => 'SERVER_TIMESTAMP'};
  const run = makeArchiveSchoolYearHandler({
    db,
    fieldValue,
    now: () => new Date('2027-06-02T00:00:00.000Z'),
  });

  const first = await run();
  assert.equal(first.activeSchoolYear, '2027-2028');
  assert.equal(first.archivedClasses, 1);
  assert.equal(db.store.get('classes/old-class').status, 'archived');
  assert.deepEqual(
      db.store.get('classes/old-class/modules/module-a'),
      nestedData,
  );
  assert.equal(
      db.store.get('school_year_archives/2026-2027').name,
      '2026-2027',
  );
  assert.equal(
      db.store.get('school_year_archives/2026-2027/classes/old-class')
          .sourcePath,
      'classes/old-class',
  );

  const second = await run();
  assert.equal(second.archivedClasses, 0);
  assert.equal(second.indexedClasses, 1);
});

test('does not roll a principal-prepared future year backwards', async () => {
  const db = new FakeFirestore([
    ['system_settings/academic_year', {activeSchoolYear: '2028-2029'}],
    ['classes/class-a', {
      name: 'CSS', schoolYear: '2027-2028', status: 'active',
    }],
  ]);
  const run = makeArchiveSchoolYearHandler({
    db,
    fieldValue: {serverTimestamp: () => 'SERVER_TIMESTAMP'},
    now: () => new Date('2027-06-02T00:00:00.000Z'),
  });
  const result = await run();
  assert.equal(result.status, 'future_school_year_configured');
  assert.equal(db.store.get('classes/class-a').status, 'active');
});
