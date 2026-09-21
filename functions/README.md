# Admin staff account deletion

The Admin Manage Teachers and Manage Trainers delete buttons call the HTTP function deleteStaffAccount in us-central1. It verifies a non-revoked Firebase ID token and requires a server-managed boolean admin custom claim. A profile role alone does not authorize deletion. It rejects self-deletion, student accounts, admin accounts, and stale target roles.

Deployment (project icteach-free):

    npm --prefix functions ci
    npx firebase-tools deploy --only functions:deleteStaffAccount --project icteach-free

The project must support Cloud Functions billing. An authorized operator must grant the intended administrator the admin: true custom claim using Firebase Admin SDK in a trusted environment, preserving existing claims. Do not grant this claim from client code or use a client-editable Firestore role as the authority. The client refreshes its token before each deletion.

Deletion removes Firebase Auth first, then recursively removes users/{uid}. Shared classes, assessment records and authored content remain. A failed profile cleanup can be retried. Assign a replacement teacher for any retained classes as needed. No accounts are deleted by tests or deployment.
