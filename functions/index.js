'use strict';
const {onRequest} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {makeDeleteStaffHandler} = require('./delete-staff');
initializeApp();
exports.deleteStaffAccount = onRequest({region: 'us-central1', cors: true, timeoutSeconds: 120},
  makeDeleteStaffHandler({auth: getAuth(), db: getFirestore()}));
