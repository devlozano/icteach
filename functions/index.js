'use strict';
const {onRequest} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {makeDeleteStaffHandler} = require('./delete-staff');
const {makeInviteStudentHandler} = require('./invite-student');
const {
  makeArchiveSchoolYearHandler,
  TIME_ZONE,
} = require('./archive-school-year');
const emailjsServiceId = defineSecret('EMAILJS_SERVICE_ID');
const emailjsTemplateId = defineSecret('EMAILJS_TEMPLATE_ID');
const emailjsPublicKey = defineSecret('EMAILJS_PUBLIC_KEY');
const emailjsPrivateKey = defineSecret('EMAILJS_PRIVATE_KEY');
initializeApp();

exports.archiveSchoolYear = onSchedule({
  schedule: '0 1 * * *',
  timeZone: TIME_ZONE,
  region: 'us-central1',
  timeoutSeconds: 540,
  memory: '256MiB',
}, makeArchiveSchoolYearHandler({
  db: getFirestore(),
  fieldValue: FieldValue,
}));
exports.deleteStaffAccount = onRequest({region: 'us-central1', cors: true, timeoutSeconds: 120},
  makeDeleteStaffHandler({auth: getAuth(), db: getFirestore()}));
exports.inviteStudentAccount = onRequest({region: 'us-central1', cors: true, timeoutSeconds: 120,
  secrets: [emailjsServiceId, emailjsTemplateId, emailjsPublicKey, emailjsPrivateKey]},
makeInviteStudentHandler({auth: getAuth(), db: getFirestore(), fieldValue: FieldValue, emailjs: {
  send: async ({toEmail, studentName, setupLink, className, teacherName, schoolYear}) => {
    const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({
        service_id: emailjsServiceId.value(), template_id: emailjsTemplateId.value(),
        user_id: emailjsPublicKey.value(), accessToken: emailjsPrivateKey.value(),
        template_params: {
          // Keep the same core fields used by the Teacher/Trainer credentials
          // template, while replacing a shared password with a secure setup link.
          email: toEmail,
          name: studentName,
          role: 'STUDENT',
          password: setupLink,
          to_email: toEmail,
          student_name: studentName,
          setup_link: setupLink,
          action_label: 'Create my password',
          credential_label: 'Secure password setup',
          class_name: className,
          teacher_name: teacherName,
          school_year: schoolYear,
        },
      }),
    });
    if (!response.ok) throw new Error(`EmailJS delivery failed: ${response.status}`);
  },
}}));
