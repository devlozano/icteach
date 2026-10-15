# Email invitation security review

Scope: replace the legacy LRN self-claim onboarding path with a server-only
email invitation flow.

Findings before this change:

1. `profileCreate` allowed an authenticated client transaction to create its
   own student profile after matching an LRN master record.
2. `claimsLrn` allowed that same client transaction to mark an LRN registered.
3. Unregistered LRN master records were readable without authentication.

Decision: student profiles and LRN registration records must be created only
by trusted server code. Staff profile creation remains available to an active
admin; Firebase Admin SDK functions bypass Firestore rules. Existing client
reads/writes outside the enrollment flow were not broadened by this change.
