# Admin staff account deletion

The Admin Manage Teachers and Manage Trainers delete buttons call the HTTP function deleteStaffAccount in us-central1. It verifies a non-revoked Firebase ID token and requires a server-managed boolean admin custom claim. A profile role alone does not authorize deletion. It rejects self-deletion, student accounts, admin accounts, and stale target roles.

Deployment (project icteach-free):

    npm --prefix functions ci
    npx firebase-tools deploy --only functions:deleteStaffAccount --project icteach-free

The project must support Cloud Functions billing. An authorized operator must grant the intended administrator the admin: true custom claim using Firebase Admin SDK in a trusted environment, preserving existing claims. Do not grant this claim from client code or use a client-editable Firestore role as the authority. The client refreshes its token before each deletion.

Deletion removes Firebase Auth first, then recursively removes users/{uid}. Shared classes, assessment records and authored content remain. A failed profile cleanup can be retried. Assign a replacement teacher for any retained classes as needed. No accounts are deleted by tests or deployment.

## Student email invitations

`inviteStudentAccount` is available from a teacher's own class roster. The server verifies both the caller's `teacher` profile and that the selected class has that caller as `teacherId`; it then creates and enrolls the student, generates a Firebase password-setup link, and delivers it through EmailJS. An Admin custom claim may also operate the endpoint for support purposes. Configure these secrets before deployment:

    firebase functions:secrets:set EMAILJS_SERVICE_ID
    firebase functions:secrets:set EMAILJS_TEMPLATE_ID
    firebase functions:secrets:set EMAILJS_PUBLIC_KEY
    firebase functions:secrets:set EMAILJS_PRIVATE_KEY

The EmailJS template requires `{{to_email}}`, `{{student_name}}`, and `{{setup_link}}`. Then deploy:

    npx firebase-tools deploy --only functions:inviteStudentAccount --project icteach-free

## Teacher Gmail CSV uploads

Teacher > Student Management > class roster > **Upload Gmail CSV** accepts CSV UTF-8 files up to 1 MB and 100 student rows. Use `Gmail,First Name,Last Name`; names are optional and `Email` is an accepted header. A one-column list is supported. No LRN or student password is required. The template contains headers only.

The teacher reviews all validated addresses before sending. Duplicate addresses in one file are removed case-insensitively. Invitations are sequential, with per-address results and stop/retry controls; successful rows are not retried in the same upload. Global service/authentication failures stop the batch and leave remaining students pending. A timeout is unconfirmed delivery, not a claim that no email was sent.

The upload calls `inviteStudentAccount` with `skipIfAlreadyInvited: true`. The server still verifies class ownership for every request, preserves existing student names, skips confirmed invitations/ordinary existing enrollment, and retains failed delivery records as retryable. `notificationSent` on the class membership is set only after EmailJS accepts the send. Single-student invitations retain explicit resend behavior. Simultaneous requests or a failure after the mail provider accepts a message can still result in duplicate mail; check inboxes before manually retrying unconfirmed delivery.

Deploy the updated Function with the existing EmailJS secrets before enabling live delivery. Frontend hosting deployment alone does not deploy this backend. Automated tests use fake recipients and do not send real email.

Live setup requires a Firebase Blaze plan: the project's current plan cannot enable Secret Manager. Upgrade billing in the Firebase console, configure the four EmailJS secrets above, then deploy the invitation Function. No billing change or real email send is performed by the upload implementation.
