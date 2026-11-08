# Final-defense readiness

## COC1 and COC2 scope

The catalog now contains 10 practical activities. Existing IDs remain stable so
historical records and lesson links still refer to the same activities.

| Panel requirement 1 | Demonstration | Competency grouping |
| --- | --- | --- |
| Install hardware and software | Assembly, cabling, OS installation, drivers | COC1 |
| Configure software | Accounts, protection, applications, peripherals, recovery | COC1 |
| Set up networks | Topology, RJ45, IP configuration | COC2 |
| Test network connectivity | Physical link, addressing, gateway, DNS, service checks | COC2 |

Motherboard identification and disassembly remain available. Standalone preventive
maintenance and hardware repair are outside the approved COC1–COC2 project scope
and have been removed from the active catalog and lesson-link choices. Old activity
links cannot start them; historical results have not been deleted.

Curriculum reference: [DepEd CSS NC II curriculum guide](https://www.deped.gov.ph/wp-content/uploads/2019/01/Computer-Systems-Servicing-NC-II-CG.pdf).
COC3 server administration and COC4 maintenance/repair are excluded. Connectivity
troubleshooting is limited to testing and correcting the configured network.
This is not complete NC II coverage or a replacement for physical assessment.

## Before the demonstration

1. Select an authorized demonstration class with separate teacher/trainer and
   student accounts. Do not use real student records for public screenshots.
2. Publish the actual instructional modules and nonempty theory quizzes.
3. In Modules > Lesson & assessment links, link every demonstrated simulation
   to its relevant published module and theory quiz. Check COC1 and COC2.
   A teacher must confirm the lesson actually teaches the simulated procedure.
4. Confirm content is unlocked, the class is active, and the student is enrolled.
   Complete prerequisite simulations normally; do not fabricate passes.
5. Demonstrate that an unfinished lesson blocks practice. Complete the lesson,
   practice the activity, and complete the linked theory quiz. Then launch the
   scored practical assessment.
6. Make one deliberate service mistake. Show the explanation, correction,
   result verification, and recorded feedback in Class Insights.
7. Confirm practice did not create a graded result. Confirm the scored result
   persists after reloading and appears for the class teacher/trainer.
8. Verify teaching-difficulty questionnaire, final system evaluation, school-year
   archive, and quiz authoring with the intended roles in the demonstration class.
   Do not archive a real active school year for a demonstration.

## Suggested demonstration sequence

- OS installation: select the authorized system disk while preserving the data
  drive; explain why an unverified disk selection is rejected.
- Software configuration: select appropriate account permissions and a narrow
  firewall rule, then verify the resulting configuration.
- Networking: show RJ45 or IP configuration, then diagnose a DNS failure using
  working IP connectivity as evidence.
- Teacher monitoring: show the student's completed assessment and error history.

These are interactive virtual procedural exercises. They do not install a real
OS, execute system commands, emulate a full network, or measure physical wiring.
Six service-decision checkpoints supplement existing sequencing, resources,
placement, IP input and result-verification controls. Incorrect decisions enter
the existing mistake/feedback pipeline; cancellation awards no operation credit.

## Two-week stabilization schedule

- Days 1–3: confirm module alignment and complete the multi-account checklist.
  Record reproducible defects with account role, page, expected/actual result.
- Days 4–7: fix blocking defects; rehearse the three advanced demonstrations
  on the actual defense laptop and a phone. Capture evidence and backup video.
- Days 8–10: freeze features; repeat grading, practice/assessment, feedback,
  enrollment and archive checks. Review privacy and access with the adviser.
- Days 11–14: fix only critical defects, rehearse explanations, verify internet,
  keep a tested release copy, and prepare an honest limitations slide.

## Verification boundaries

397 Flutter tests passed with one existing skip. Scope-correction checks cover both catalogs, blocked historical links, retained
prerequisites, service decisions, layouts and existing learning flows.

Automated tests and a successful upload do not establish live-account acceptance.
Real lesson/quiz alignment, role access, production save/reload and the final
demonstration remain explicit acceptance steps. Existing broad legacy Firestore
permissions and client-side assessment scoring are separate limitations; this
restoration does not claim to harden them.
