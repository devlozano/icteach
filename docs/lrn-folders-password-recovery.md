# LRN folders and password recovery

## Behavior

Admin > LRN Master List opens existing records in **Unfiled**. Create a **Batch** or **Class** folder and select it before adding an LRN or importing CSV. Use each record's folder icon to move it. Duplicate imports preserve the existing record, folder, and registration status.

Each LRN has a delete action with confirmation. Pending LRNs are deleted in a transaction. Registered LRNs are removed from the active list with `archived: true`; their registration identity is retained to prevent duplicate registration. Student Auth accounts, profiles, and progress are not deleted. A concurrent registration causes the deletion transaction to retry and retain the claimed record.

Each Batch or Class folder also has a delete icon. Deleting a folder processes all LRNs assigned to it using the same safety rule: pending LRNs are deleted and registered LRNs are archived. The protected **Unfiled** folder cannot be deleted.

Teacher navigation includes **Quiz & Assessment** after Module Management. It opens the existing quiz and assignment management flows after the teacher chooses a class.

**Forgot Password?** on the mobile and staff web login screens opens the same recovery form. Teacher, trainer, and student profiles also have **Reset password**. Firebase Auth sends a secure email link; its hosted action page lets the account owner choose a new password. Success messaging does not disclose whether an email is registered. Network errors support retry, and repeated sends are disabled while sending.

## Release requirements

- Deploy `firestore.rules` with the app update. The local implementation has not deployed them.
- The intended administrator needs the existing server-managed boolean `admin: true` custom claim, as already required by staff account deletion. A Firestore profile role is not sufficient. Assign claims only in a trusted Admin SDK environment, preserving existing claims, then sign out and in to refresh the ID token. See `functions/README.md`.
- No collection migration is needed. Missing folder IDs display as Unfiled. New folders live in `lrn_folders`; LRN document paths remain `lrn_master_list/{lrn}`.
- Live reset-email delivery and Firebase's hosted password action page need a test account smoke test. Automated tests inject the email sender; they do not send messages to real accounts.

## Local checks

```powershell
flutter test test/password_reset_dialog_test.dart test/lrn_management_test.dart test/lrn_registration_test.dart test/lrn_csv_import_test.dart
npx.cmd -y firebase-tools@latest emulators:exec --only firestore --project demo-icteach-lrn --config firebase.lrn-test.json "node --test test/firestore/lrn-management.test.mjs"
```

The rules tests target the actual root `firestore.rules`, not the older invitation-code prototype in `test/firestore/enrollment.rules`.

## Scoped security audit

The LRN collections are excluded from the legacy authenticated catch-all. Folder and LRN administration require a signed admin claim, folder names and references are validated, and students can only atomically claim an available LRN with matching profiles. Registered records cannot be physically deleted or reset through client rules.

The unrelated collection catch-all remains a pre-existing critical issue. This change does not claim to secure the whole application's database. Exact pending-LRN lookups remain available before authentication to preserve the requested registration flow; this is eligibility validation, not proof of identity.

```json
{
  "score": 1,
  "summary": "LRN management is restricted and emulator-tested; the overall database remains unsafe because unrelated collections retain the existing authenticated catch-all.",
  "findings": [
    {
      "check": "Field-Level vs. Identity-Level Security",
      "severity": "critical",
      "issue": "Authenticated users retain broad access to unrelated collections, including profiles, through the legacy catch-all.",
      "recommendation": "Migrate unrelated collections to ownership and trusted-role policies in a separately validated security change."
    },
    {
      "check": "Authority Source",
      "severity": "moderate",
      "issue": "Knowing an available LRN is sufficient for pre-account eligibility lookup; this intentionally preserves the existing LRN-only flow.",
      "recommendation": "Use a school-approved identity-verification process if proof of student identity is required."
    }
  ]
}
```

## Verification (2026-09-29)

- All 263 Flutter tests passed, including 38 targeted recovery, LRN, import, and registration tests.
- All 6 Firestore emulator tests passed against the root rules.
- Targeted analysis of the new feature files and tests: no issues.
- Whole-project analysis still reports existing informational lint findings; no error or warning diagnostics were present in the captured final output (some findings were emitted twice).
- Web release output generated in `build/web`. Optional WebAssembly dry-run warnings remain in existing `connectivity_plus` and `flutter_tts` dependencies; the JavaScript web build completed.
- Android debug APK generated in `build/app/outputs/flutter-apk/app-debug.apk`.
- No production deployment or real-account email delivery test was performed.
