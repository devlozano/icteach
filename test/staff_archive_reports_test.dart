import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/screens/staff_archive_reports_page.dart';

void main() {
  test('school-year summaries group classes and unique students', () {
    final summaries = buildStaffSchoolYearSummaries([
      {
        'schoolYear': '2026-2027',
        'status': 'archived',
        'enrolledStudentIds': ['a', 'b'],
      },
      {
        'schoolYear': '2026-2027',
        'status': 'archived',
        'enrolledStudentIds': ['b', 'c'],
      },
      {
        'schoolYear': '2027-2028',
        'status': 'active',
        'enrolledStudentIds': ['d'],
      },
    ]);

    expect(summaries.map((item) => item.schoolYear), [
      '2027-2028',
      '2026-2027',
    ]);
    expect(summaries.first.activeClasses, 1);
    expect(summaries.first.archivedClasses, 0);
    expect(summaries.last.classCount, 2);
    expect(summaries.last.archivedClasses, 2);
    expect(summaries.last.studentCount, 3);
  });
}
