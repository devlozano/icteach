const {test} = require('node:test');
const assert = require('node:assert/strict');
const {makeInviteStudentHandler} = require('../invite-student');

function run({token = {uid: 'teacher'}, body = {classId: 'class', email: 'student@example.com'}, db} = {}) {
  const req = {method: 'POST', get: () => 'Bearer token', body};
  const res = {status(code) { this.code = code; return this; }, json(value) { this.body = value; return this; }};
  const auth = {verifyIdToken: async () => token};
  return makeInviteStudentHandler({auth, db: db || {}, fieldValue: {arrayUnion: value => value}, emailjs: {send: async () => {}}, logger: {error() {}}})(req, res).then(() => res);
}

test('rejects callers without an assigned teacher role before account creation', async () => {
  const db = {collection: name => ({doc: id => ({get: async () => name === 'users' ? {exists: true, data: () => ({role: 'student'})} : {exists: true, data: () => ({teacherId: 'teacher'})}})})};
  const result = await run({db});
  assert.equal(result.code, 403);
  assert.equal(result.body.error, 'teacher-class-required');
});

for (const profile of [{role: 'admin'}, {role: 'trainer'}, {role: 'teacher', isActive: false}]) {
  test(`rejects ${JSON.stringify(profile)} even with an admin claim`, async () => {
    const db = {collection: name => ({doc: () => ({get: async () => ({exists: true,
      data: () => name === 'users' ? profile : {teacherId: 'teacher'}})})})};
    const result = await run({token: {uid: 'teacher', admin: true}, db});
    assert.equal(result.code, 403);
  });
}

test('rejects malformed or missing class identifiers', async () => {
  const result = await run({body: {classId: 'classes/other', email: 'student@example.com'}});
  assert.equal(result.code, 400);
  assert.equal(result.body.error, 'invalid-class');
});

function fixture({profile, membership, teacherId = 'teacher', sendFails = false} = {}) {
  const store = new Map([
    ['users/teacher', {role: 'teacher'}],
    ['classes/class', {teacherId, enrolledStudentIds: membership ? ['student'] : []}],
  ]);
  if (profile) store.set('users/student', {...profile});
  if (membership) store.set('classes/class/students/student', {...membership});
  let created = 0;
  const sent = [];
  let fails = sendFails;
  function ref(path) {
    return {path,
      get: async () => ({exists: store.has(path), data: () => store.get(path)}),
      collection: name => ({doc: id => ref(`${path}/${name}/${id}`)}),
      set: async (data) => store.set(path, {...store.get(path), ...data}),
    };
  }
  const db = {
    collection: name => ({doc: id => ref(`${name}/${id}`)}),
    batch() {
      const changes = [];
      return {
        set(doc, data) { changes.push([doc.path, data]); return this; },
        update(doc, data) { changes.push([doc.path, data]); return this; },
        async commit() {
          for (const [path, data] of changes) {
            const old = store.get(path) || {};
            if (data.enrolledStudentIds?.union) {
              data.enrolledStudentIds = [...new Set([...(old.enrolledStudentIds || []), data.enrolledStudentIds.union])];
            }
            store.set(path, {...old, ...data});
          }
        },
      };
    },
  };
  const auth = {
    verifyIdToken: async () => ({uid: 'teacher'}),
    getUserByEmail: async () => {
      if (!profile && !created) throw {code: 'auth/user-not-found'};
      return {uid: 'student'};
    },
    createUser: async () => { created++; return {uid: 'student'}; },
    generatePasswordResetLink: async () => 'https://example.com/test-only-setup',
  };
  const handler = makeInviteStudentHandler({auth, db,
    fieldValue: {arrayUnion: uid => ({union: uid})},
    emailjs: {send: async value => { if (fails) throw Error('provider unavailable'); sent.push(value); }},
    logger: {error() {}},
  });
  return {
    store, sent, created: () => created, recover: () => { fails = false; },
    async request(body = {}) {
      const req = {method: 'POST', get: () => 'Bearer test', body: {
        classId: 'class', email: 'student@example.com', skipIfAlreadyInvited: true, ...body,
      }};
      const res = {status(code) { this.code = code; return this; }, json(value) { this.body = value; return this; }};
      await handler(req, res);
      return res;
    },
  };
}

test('CSV invitation creates and enrolls a student and records confirmed delivery', async () => {
  const f = fixture();
  const result = await f.request({firstName: 'Ana', lastName: 'Santos'});
  assert.equal(result.code, 200);
  assert.equal(result.body.notificationSent, true);
  assert.equal(f.created(), 1);
  assert.equal(f.sent[0].studentName, 'Ana Santos');
  assert.equal(f.store.get('classes/class/students/student').notificationSent, true);
  assert.deepEqual(f.store.get('classes/class').enrolledStudentIds, ['student']);
});

test('re-upload skips confirmed invitations without sending or creating an account again', async () => {
  const f = fixture();
  await f.request();
  const again = await f.request();
  assert.equal(again.body.skipped, true);
  assert.equal(f.sent.length, 1);
  assert.equal(f.created(), 1);
});

test('new class invitation preserves existing school-managed identity', async () => {
  const profile = {role: 'student', firstName: 'Existing', lastName: 'Name', name: 'Existing Name', lrn: '123456789012'};
  const f = fixture({profile});
  const result = await f.request({firstName: 'Changed', lastName: 'Upload'});
  assert.equal(result.code, 200);
  assert.deepEqual(f.store.get('users/student'), profile);
  assert.equal(f.sent[0].studentName, 'Existing Name');
  assert.equal(f.store.get('classes/class/students/student').firstName, 'Existing');
});

test('existing ordinary class enrollment is skipped by CSV import', async () => {
  const f = fixture({profile: {role: 'student', name: 'Existing'}, membership: {name: 'Existing'}});
  const result = await f.request();
  assert.equal(result.body.skipped, true);
  assert.equal(f.sent.length, 0);
});

test('failed email delivery is not recorded as sent and can be retried', async () => {
  const f = fixture({sendFails: true});
  const failed = await f.request();
  assert.equal(failed.code, 500);
  assert.equal(f.store.get('classes/class/students/student').notificationSent, false);
  f.recover();
  const retried = await f.request();
  assert.equal(retried.body.notificationSent, true);
  assert.equal(f.created(), 1);
  assert.equal(f.sent.length, 1);
});

test('single-student explicit resend remains available', async () => {
  const f = fixture();
  await f.request();
  const result = await f.request({skipIfAlreadyInvited: false});
  assert.equal(result.body.notificationSent, true);
  assert.equal(f.sent.length, 2);
});

test('another teacher cannot use CSV upload to invite into this class', async () => {
  const f = fixture({teacherId: 'other-teacher'});
  assert.equal((await f.request()).code, 403);
  assert.equal(f.created(), 0);
  assert.equal(f.sent.length, 0);
});

test('CSV upload rejects non-student accounts without overwriting them', async () => {
  const f = fixture({profile: {role: 'trainer', name: 'Staff'}});
  assert.equal((await f.request()).code, 409);
  assert.deepEqual(f.store.get('users/student'), {role: 'trainer', name: 'Staff'});
  assert.equal(f.sent.length, 0);
});
