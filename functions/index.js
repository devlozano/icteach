'use strict';
const {onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {makeDeleteStaffHandler} = require('./delete-staff');
const {makeInviteStudentHandler} = require('./invite-student');
const emailjsServiceId = defineSecret('EMAILJS_SERVICE_ID');
const emailjsTemplateId = defineSecret('EMAILJS_TEMPLATE_ID');
const emailjsPublicKey = defineSecret('EMAILJS_PUBLIC_KEY');
const emailjsPrivateKey = defineSecret('EMAILJS_PRIVATE_KEY');
initializeApp();
exports.deleteStaffAccount = onRequest({region: 'us-central1', cors: true, timeoutSeconds: 120},
  makeDeleteStaffHandler({auth: getAuth(), db: getFirestore()}));
exports.inviteStudentAccount = onRequest({region: 'us-central1', cors: true, timeoutSeconds: 120,
  secrets: [emailjsServiceId, emailjsTemplateId, emailjsPublicKey, emailjsPrivateKey]},
makeInviteStudentHandler({auth: getAuth(), db: getFirestore(), fieldValue: FieldValue, emailjs: {
  send: async ({toEmail, studentName, setupLink}) => {
    const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({
        service_id: emailjsServiceId.value(), template_id: emailjsTemplateId.value(),
        user_id: emailjsPublicKey.value(), accessToken: emailjsPrivateKey.value(),
        template_params: {to_email: toEmail, student_name: studentName, setup_link: setupLink},
      }),
    });
    if (!response.ok) throw new Error(`EmailJS delivery failed: ${response.status}`);
  },
}}));
