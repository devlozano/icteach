'use strict';
const crypto = require('crypto');

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function makeInviteStudentHandler({auth, db, fieldValue, emailjs, logger = console}) {
  return async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({error: 'method-not-allowed'});
    const bearer = /^Bearer (.+)$/.exec(req.get('authorization') || '');
    if (!bearer) return res.status(401).json({error: 'unauthenticated'});
    let caller;
    try { caller = await auth.verifyIdToken(bearer[1], true); }
    catch (_) { return res.status(401).json({error: 'unauthenticated'}); }
    const {email, firstName = '', lastName = '', classId} = req.body || {};
    const address = typeof email === 'string' ? email.trim().toLowerCase() : '';
    if (!emailPattern.test(address) || address.length > 254) return res.status(400).json({error: 'invalid-email'});
    if (![firstName, lastName].every((value) => typeof value === 'string' && value.trim().length <= 80)) {
      return res.status(400).json({error: 'invalid-name'});
    }
    if (typeof classId !== 'string' || !classId.trim() || classId.length > 128 || classId.includes('/')) {
      return res.status(400).json({error: 'invalid-class'});
    }
    try {
      const classroom = db.collection('classes').doc(classId);
      const [callerProfile, classSnapshot] = await Promise.all([
        db.collection('users').doc(caller.uid).get(), classroom.get(),
      ]);
      if (!classSnapshot.exists) return res.status(404).json({error: 'class-not-found'});
      const isAssignedTeacher = callerProfile.data()?.role === 'teacher' &&
        classSnapshot.data()?.teacherId === caller.uid;
      if (caller.admin !== true && !isAssignedTeacher) return res.status(403).json({error: 'teacher-class-required'});
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
      await db.batch()
        .set(profile, profileData, {merge: true})
        .set(db.collection('students').doc(user.uid), profileData, {merge: true})
        .set(classroom.collection('students').doc(user.uid), {...profileData, classId}, {merge: true})
        .update(classroom, {enrolledStudentIds: fieldValue.arrayUnion(user.uid)})
        .commit();
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
