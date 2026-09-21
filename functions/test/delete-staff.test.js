const {test} = require('node:test');
const assert = require('node:assert/strict');
const {makeDeleteStaffHandler} = require('../delete-staff');
function setup(overrides = {}) {
  const calls = [];
  const auth = {
    verifyIdToken: async (_, revoked) => { assert.equal(revoked, true); return {uid: 'admin', admin: true}; },
    getUser: async () => ({customClaims: {}}),
    deleteUser: async uid => calls.push('auth:'+uid),
    ...overrides.auth,
  };
  const profile = {get: async () => ({exists: true, data: () => ({role: overrides.role ?? 'trainer'})})};
  const db = {collection: () => ({doc: uid => { assert.equal(uid, 'target'); return profile; }}), recursiveDelete: async () => calls.push('profile'), ...overrides.db};
  const req = {method: 'POST', get: () => 'Bearer token', body: {uid: 'target', role: overrides.role ?? 'trainer'}, ...overrides.req};
  const res = {status(code) {this.code=code; return this;}, json(body) {this.body=body; return this;}};
  return {calls, run: async () => {await makeDeleteStaffHandler({auth, db, logger: {error(){}}})(req,res); return res;}};
}
for (const role of ['teacher','trainer']) test('admin deletes '+role+' Auth before profile', async () => {
  const f=setup({role});assert.equal((await f.run()).code,200);assert.deepEqual(f.calls,['auth:target','profile']);
});
test('requires verified bearer token', async () => {const f=setup({req:{get:()=>''}});assert.equal((await f.run()).code,401);assert.deepEqual(f.calls,[]);});
test('rejects invalid or revoked token', async () => {const f=setup({auth:{verifyIdToken:async()=>{throw Error('revoked');}}});assert.equal((await f.run()).code,401);});
test('profile role cannot authorize deletion', async () => {const f=setup({auth:{verifyIdToken:async()=>({uid:'admin',role:'admin'})}});assert.equal((await f.run()).code,403);assert.deepEqual(f.calls,[]);});
test('rejects self-deletion', async () => {const f=setup({req:{body:{uid:'admin',role:'trainer'}}});assert.equal((await f.run()).code,403);});
test('rejects student target', async () => {const f=setup({req:{body:{uid:'target',role:'student'}}});assert.equal((await f.run()).code,400);});
test('rejects path traversal uid', async () => {const f=setup({req:{body:{uid:'users/target',role:'trainer'}}});assert.equal((await f.run()).code,400);});
test('rejects changed target role', async () => {const f=setup({req:{body:{uid:'target',role:'teacher'}}});assert.equal((await f.run()).code,409);assert.deepEqual(f.calls,[]);});
test('protects administrator with staff profile', async () => {const f=setup({auth:{getUser:async()=>({customClaims:{admin:true}})}});assert.equal((await f.run()).code,403);assert.deepEqual(f.calls,[]);});
test('Auth failure preserves profile', async () => {const f=setup({auth:{deleteUser:async()=>{throw Error('offline');}}});assert.equal((await f.run()).code,500);assert.deepEqual(f.calls,[]);});
test('retry finishes cleanup after Auth already deleted', async () => {const f=setup({auth:{getUser:async()=>{throw {code:'auth/user-not-found'};}}});assert.equal((await f.run()).code,200);assert.deepEqual(f.calls,['profile']);});
test('profile failure is retryable and reported', async () => {const f=setup({db:{recursiveDelete:async()=>{throw Error('offline');}}});assert.equal((await f.run()).code,500);assert.deepEqual(f.calls,['auth:target']);});
test('rejects GET', async () => {const f=setup({req:{method:'GET'}});assert.equal((await f.run()).code,405);});
