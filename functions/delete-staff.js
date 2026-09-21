'use strict';
// Auth is injected so authorization and failure recovery can be tested without deleting real users.
function makeDeleteStaffHandler({auth, db, logger = console}) {
  return async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({error: 'method-not-allowed'});
    const match = /^Bearer (.+)$/.exec(req.get('authorization') || '');
    if (!match) return res.status(401).json({error: 'unauthenticated'});
    let caller;
    try { caller = await auth.verifyIdToken(match[1], true); }
    catch (_) { return res.status(401).json({error: 'unauthenticated'}); }
    if (caller.admin !== true) return res.status(403).json({error: 'admin-required'});
    const {uid, role} = req.body || {};
    if (typeof uid !== 'string' || !uid.trim() || uid.length > 128 || uid.includes('/') || !['teacher', 'trainer'].includes(role)) {
      return res.status(400).json({error: 'invalid-target'});
    }
    if (uid === caller.uid) return res.status(403).json({error: 'self-deletion-forbidden'});
    try {
      const profile = db.collection('users').doc(uid);
      const doc = await profile.get();
      if (!doc.exists || doc.data().role !== role) return res.status(409).json({error: 'target-role-changed'});
      let target;
      try { target = await auth.getUser(uid); }
      catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
      if (target?.customClaims?.admin === true) return res.status(403).json({error: 'protected-admin'});
      // Remove sign-in first. A retry can finish profile cleanup if it fails afterward.
      if (target) await auth.deleteUser(uid);
      await db.recursiveDelete(profile);
      return res.status(200).json({deleted: true});
    } catch (error) {
      logger.error('Staff account deletion failed', error);
      return res.status(500).json({error: 'deletion-incomplete'});
    }
  };
}
module.exports = {makeDeleteStaffHandler};
