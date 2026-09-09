# Staff workspace update

Teacher navigation: Overview, Classes, Discussions, Class Monitoring, Profile, Feedback.
Trainer navigation: Overview, Discussions, Profile, Class Monitoring, Feedback.
Admin Reports now shows student counts and NC II results; Feedback contains the helpfulness survey summary and existing course/system/simulation responses.
School Profile edits the shared school name and HTTPS logo image URL. A school icon is shown until the actual school branding is configured.

## Data
- users/{studentUid}: nc2Passed (bool), nc2ClassId, nc2UpdatedBy, nc2UpdatedAt. Missing/false is labelled No recorded pass, not Failed. Results are deduplicated by student, not class membership.
- app_helpfulness_surveys/{studentUid}: studentId, version (1), ratings (q0 through q3, integer 1 to 5), comment (up to 2000 characters), updatedAt. Saving replaces the same response, avoiding duplicate counts.
- settings/school_profile: name, logoUrl, updatedBy, updatedAt.

## Access and rollout
Uses the existing icteach-free default STANDARD Firestore database. No production data or rules were changed during implementation. Client-side teacher updates check the class owner and enrollment in a transaction; these checks are not server-side authorization.
The repository has an enrollment-only rules prototype, not a full deployable LMS ruleset. Before production rollout, verify that the complete live rules restrict NC II fields to the assigned teacher, survey writes to the student document owner with rating validation, and school profile writes to admins. Staff survey reads currently use collection queries and filter by enrolled students in the UI; scoped server-side authorization needs matching query design. Existing broad authenticated access must not be treated as protection of these new fields.

## Manual acceptance
1. As a teacher, open Class Monitoring and record a student pass; confirm the same unique student updates in admin Reports.
2. As a student, submit and edit Feedback; verify one response contributes to all four summary graphs.
3. As admin, save school name/logo and confirm navigation identity updates.
4. On a desktop window, open class/detail pages, return using the persistent sidebar, and confirm the same selected section.
5. Verify denied writes show errors and do not claim successful saves.

## Follow-up: management, assessment and printing
- Logout dialogs no longer trigger a second persistent sidebar: the root navigation observer tracks PageRoutes separately from modal routes. Signing out explicitly clears the registered staff shell.
- Removed the teacher greeting and the separate Lesson Content form/display; existing stored text is retained when old modules are edited.
- Added Student Management and Module Management entries for teachers/trainers; roster removal is confirmed and writes membership changes in a single batch.
- Pre-assessment and quiz display order randomizes both questions and options once per session. Answers remain indexed to their original questions/options for grading and stored-result compatibility. Pre-assessment review/printing shows submitted answers only.
- classes/{classId}/module_access/{moduleId}_{studentId}: unique student access, resource openings, download requests and confirmed downloads. Native save cancellation is not counted; browser download requests are unconfirmed, not labelled downloaded. External preview links are opened separately and cannot establish a saved-file count. Tracking begins with this update.
- Print actions cover NC II monitoring, survey summaries, course/simulation feedback, class insights, module access, rosters, pre-assessment, quiz results, student progress, simulation result dialogs and admin summaries. PDFs repeat the configured college name/logo and page numbers; set branding under Admin > School Profile before printing. Roboto font files and their license are bundled for offline PDF text rendering.
- Local validation includes randomized-scoring, unique-download-count, logout-modal, and multipage PDF regressions. Live Firebase authorization and actual device print/save dialogs still require acceptance testing.
