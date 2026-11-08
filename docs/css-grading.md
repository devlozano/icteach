# Computer Systems Servicing grading

The teacher's Class Insights > Grades tab records three terms for senior-high
TechPro CSS, as confirmed by the project owner. Weights are Written/Oral Works
15%, Performance Tasks 65%, and Examinations 20%.

## Computation

Teachers enter total earned points and total possible points for WW and PT,
and separate earned/possible pairs for ST1, ST2 and the term examination.
Each percentage is earned / possible * 100. The exam percentage is
0.30 * ST1% + 0.30 * ST2% + 0.40 * TE%. Initial grade is
0.15 * WW% + 0.65 * PT% + 0.20 * exam%.

For SY 2026–2027, the exact lower thresholds in Annex D's adjusted transmutation
table map the initial grade to 60–100 (70 maps to 75). Comparisons retain
precision and do not round an initial grade up across a threshold. Two-decimal
values in the UI are presentation only. From SY 2027–2028, the initial grade is
reported directly as a whole-number term grade, without transmutation.
The final grade is the rounded mean of three completed term grades.
Missing pairs remain incomplete; actual zero scores are retained.

School year is explicitly entered at setup and immutable thereafter, preventing
silent reinterpretation of historical grades. Create a new class for a new school
year. The underlying calculation utility also documents TLE and transitional
Grade 12 TVL weights, but the project's gradebook setup only permits TechPro.

## Reference reconciliation

Official source: [DepEd Order 015, s. 2026](https://www.deped.gov.ph/wp-content/uploads/DO_s2026_015r.pdf),
sections 45–52 and Annex D, printed pages 35–37. The downloaded official PDF was
visually inspected because it is scanned. The three-term calendar is documented
in [DepEd Order 009, s. 2026](https://www.deped.gov.ph/wp-content/uploads/DO_s2026_009r.pdf).

The supplied Sample grading.xlsx contains COURSE INFO, PRELIM, MIDTERM,
FINALS and OVERALL GRADE sheets from a university grading template. PRELIM
D8:H8 assigns 10% quizzes, 5% assignments, 5% attendance/class participation,
40% activities/projects and 40% exams. Its quiz conversions use a different
passing threshold and floor. These formulas are not the DepEd TechPro method.
Its earned/possible score-entry concept was retained, not its institutional
weights or conversion formulas. The source workbook was not modified.

## Persistence and boundaries

Records live at css_gradebooks/{teacherUid}/classes/{classId}/records/{studentId}_{term}.
The parent stores the immutable profile and school-year start. Records store
validated score pairs and server timestamps. Term and final grades are computed
from these inputs, not stored as editable overrides. Firestore rules restrict
access to the active owning teacher, validate enrollment and term numbers,
and exclude this namespace from the existing broad authenticated fallback.

This is a teacher-entered component-total gradebook. Existing quiz and simulation
averages are activity-progress statistics and are not automatically imported:
they lack authoritative grading-term and assessment-component assignments.
Teachers retain individual task records as evidence. Export includes the three
term grades, final grade, school year, profile and descriptor. The existing
activity export is now explicitly labeled as progress rather than grades.

No production student records were changed during development. Deployment and
an authenticated live save/reload still require verification. Existing permissive
rules for unrelated collections remain outside this change; the new namespace
does not inherit that catch-all access.

## Local validation

Seven Flutter tests cover all 41 transmutation thresholds, unequal exam maxima,
both supported numeric regimes, incomplete data, persistence, immutable setup,
and a 390px mobile edit/save/reload flow. Four Firestore emulator tests cover
valid saves, TechPro-only setup, unauthorized reads/writes and malformed records.
The rules compiled in a Firebase dry run. Full-project analysis completed with
informational lints; focused analysis of the new files reported no issues.
The web release build also completed successfully. No deployment was performed.
