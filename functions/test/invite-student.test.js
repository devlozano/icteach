const {test} = require('node:test');
const assert = require('node:assert/strict');
const {makeInviteStudentHandler} = require('../invite-student');

function run({token = {uid: 'teacher'}, body = {classId: 'class', email: 'student@example.com'}, db} = {}) {
  const req = {method: 'POST', get: () => 'Bearer token', body};
  const res = {status(code) { this.code = code; return this; }, json(value) { this.body = value; return this; }};
  const auth = {verifyIdToken: async () => token};
  return makeInviteStudentHandler({auth, db: db || {}, fieldValue: {arrayUnion: value => value}, emailjs: {send: async () => {}}, logger: {error() {}}})(req, res).then(() => res);
}

test('rejects callers without a teacher role or admin claim before account creation', async () => {
  const db = {collection: name => ({doc: id => ({get: async () => name === 'users' ? {exists: true, data: () => ({role: 'student'})} : {exists: true, data: () => ({teacherId: 'teacher'})}})})};
  const result = await run({db});
  assert.equal(result.code, 403);
  assert.equal(result.body.error, 'teacher-class-required');
});

test('rejects malformed or missing class identifiers', async () => {
  const result = await run({body: {classId: 'classes/other', email: 'student@example.com'}});
  assert.equal(result.code, 400);
  assert.equal(result.body.error, 'invalid-class');
});
