# Panel requirement integration and testing

Updated 6 September 2026. These are application integrations, not a claim of production acceptance or TESDA certification.

## Advanced simulation restoration

The active catalog again includes OS installation, software configuration,
network topology, connectivity diagnostics, maintenance and repair, alongside
the six retained practicals. Maintenance and repair display COC4 while preserving
historical record IDs. Ten evidence-based service decisions block incorrect
actions and feed the existing mistake feedback. See [defense readiness](DEFENSE_READINESS.md)
for module alignment, demonstration steps, scope limits and the stabilization plan.

## Teacher/trainer setup (required before student testing)

1. Publish the actual lessons and nonempty terminology/theory quizzes using the existing module/quiz CMS.
2. Open a class → Modules → **Lesson & assessment links** (branching-path icon).
3. Select each simulation and link its relevant published lesson and a teacher/trainer theory quiz. Configure standalone quizzes too. Simulations are fixed scenarios, not editable quiz questions.
4. Review each link against the instructional module. A link establishes the app prerequisite; a teacher must verify curricular accuracy. An existing theory quiz's lesson link is preserved when reused.
5. Unlock appropriate content through Content Lock Settings.

Unconfigured activities intentionally show a setup message instead of allowing students to bypass learning. Existing grades and simulation passes are preserved; new practice is kept separately.

## Requirement map

| Panel item | Integrated behavior / location |
| --- | --- |
| 1. Advanced learning | Existing OS installation, software configuration, maintenance, hardware repair and network-diagnostic scenarios now support explicit lesson/quiz links. These are interactive virtual procedural exercises, not a real operating-system installer or packet emulator. |
| 2. Clear user roles | Help icon in student home and class detail describes administrator, teacher/adviser, trainer and student responsibilities. |
| 3. Trainer and teaching difficulty | Existing trainer dashboard/CMS plus built-in Teaching & learning check-in under Questionnaires & Evaluations. Ratings explicitly distinguish clarity from difficulty; responses identify the student and class teacher. |
| 4. Knowledge before activity | The linked published module must be marked complete before practice or assessment. Existing diagnostic gate remains on module entry. This records study completion, not proof of comprehension. |
| 5. Two-part assessment and practice | Ungraded simulation practice; linked theory quiz before scored simulation; practice never writes quiz_results, simulation_progress or completed_content. Theory completion, not a passing grade, opens the simulation stage. Quizzes are single scored attempts with no separate quiz practice. |
| 5c. Informative feedback | Simulation feedback retains corrected resource, sequence and compatibility mistakes. RJ45 results include possible open/short/miswire/split-pair causes and distinguish physical wiring from IP/VLAN issues. These are educational possibilities, not diagnoses of physical equipment. |
| 6. Quiz CMS | Existing teacher/trainer Create/Edit/Publish/Delete quiz pages remain the authoring source. The learning-path manager references these quizzes without exposing simulation editing. |
| 7. Monitoring | Class Insights → history icon shows newly recorded lesson opening/completion, practice completion and scored quiz/simulation completion; simulation mistakes are expandable. Existing grades/progress/feedback reports remain available. No keystroke or background surveillance. |
| 8. School years | Existing Admin Settings academic-year rollover archives without deletion. Student dashboard resolves authoritative class status, ignores archived memberships and allows joining a new active class. Archived class detail directs staff to historical reports; new assessment/practice and lesson-progress saves are blocked. |
| 9. Final system evaluation | Completing a module offers an Evaluate action; Questionnaires & Evaluations also exposes the form. It opens only after all published lessons are marked complete. Usability, usefulness, reliability and improvement comments appear in Class Insights Feedback. |

## Manual acceptance checklist

Automated verification: 22 tests passed; static analysis has no errors/warnings (324 informational findings). The automated suite does not replace the following multi-account checks.

- Use separate admin, teacher, trainer and student test accounts in an authorized test class.
- Verify unmapped activity, missing lesson, missing practice and missing theory each block the appropriate next stage.
- Complete diagnostic and linked lesson. Complete simulation practice and inspect feedback. Confirm no simulation grade exists yet.
- Complete the scored theory quiz once. Confirm duplicate submission cannot overwrite it.
- Complete simulation practice, then simulation assessment. Verify only assessment affects grades/progress; check the timeline and corrected-error history.
- Make deliberate RJ45 resource/sequence/placement mistakes and inspect feedback on a small screen.
- Submit teaching feedback; verify staff can see the named student, individual rating prompts/values and full comment.
- Verify system evaluation is blocked with unfinished lessons, then available after the final published lesson.
- In a test class, archive the old year and join a current-year class without deleting historical membership or results. Verify the dashboard selects the active class.
- Test reconnect/retry, content locking while open, and changes to lesson links during a session.

## Data and release limitations

- New collections: `classes/{classId}/learning_paths`, `users/{uid}/practice_progress`, top-level `activity_events`. Existing `questionnaire_responses` stores built-in evaluations.
- Activity history starts with this update; old activity timestamps are not fabricated. Opening practice/assessment sessions is also recorded, but is not evidence of completion. Feedback is identified, not anonymous.
- Lesson/practice/theory and active-class checks are revalidated before saving assessments. They are client-side checks, not backend authorization or tamper-proof scoring.
- Previously inspected live Firestore rules permit every signed-in user to read/write broadly. Production release requires reviewed role/membership rules, protected grades and role fields, rules tests, and privacy review for student feedback. No live rules or production deployment were changed for this integration.
- Full archived-data immutability requires those backend rules; existing legacy mutation paths are not a secure archive boundary.
- Real-account acceptance, Cloudinary uploads and Hostinger deployment must still be verified. Do not label the project 100% accepted based on a local build alone.
