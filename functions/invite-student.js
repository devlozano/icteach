'use strict';
const crypto = require('crypto');

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function makeInviteStudentHandler({auth, db, emailjs, logger = console}) {
  return async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({error: 'method-not-allowed'});
    const bearer = /^Bearer (.+)$/.exec(req.get('authorization') || '');
    if (!bearer) return res.status(401).json({error: 'unauthenticated'});
    let caller;
    try { caller = await auth.verifyIdToken(bearer[1], true); }
    catch (_) { return res.status(401).json({error: 'unauthenticated'}); }
    if (caller.admin !== true) return res.status(403).json({error: 'admin-required'});
    const {email, firstName = '', lastName = ''} = req.body || {};
    const address = typeof email === 'string' ? email.trim().toLowerCase() : '';
    if (!emailPattern.test(address) || address.length > 254) return res.status(400).json({error: 'invalid-email'});
    if (![firstName, lastName].every((value) => typeof value === 'string' && value.trim().length <= 80)) {
      return res.status(400).json({error: 'invalid-name'});
    }
    try {
      let user;
      let created = false;
      try { user = await auth.getUserByEmail(address); }
      catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
        user = await auth.createUser({email: address, password: crypto.randomBytes(32).toString('base64url')});
        created = true;
      }
      const profile = db.collection('users').doc(user.uid);
      const existing = await profile.get();
      if (existing.exists && existing.data().role !== 'student') return res.status(409).json({error: 'email-in-use'});
      const name = [firstName.trim(), lastName.trim()].filter(Boolean).join(' ') || 'Student';
      const now = new Date();
      const profileData = {uid: user.uid, email: address, role: 'student', firstName: firstName.trim(), lastName: lastName.trim(), name, displayName: name, invitationStatus: 'pending', invitedAt: now, invitedBy: caller.uid};
      await db.batch().set(profile, profileData, {merge: true}).set(db.collection('students').doc(user.uid), profileData, {merge: true}).commit();
      const setupLink = await auth.generatePasswordResetLink(address);
      await emailjs.send({toEmail: address, studentName: name, setupLink});
      return res.status(200).json({uid: user.uid, email: address, created, notificationSent: true});
    } catch (error) {
      logger.error('Student invitation failed', error);
      return res.status(500).json({error: 'invite-failed'});
    }
  };
}
module.exports = {makeInviteStudentHandler};
