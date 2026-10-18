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
