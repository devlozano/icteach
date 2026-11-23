import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/utils/academic_year_validation.dart';

void main() {
  const currentYear = 2026;

  test('accepts the present year and future start years', () {
    expect(
      AcademicYearValidation.startYearError('2026', currentYear: currentYear),
      isNull,
    );
    expect(
      AcademicYearValidation.schoolYear('2035', currentYear: currentYear),
      '2035-2036',
    );
  });

  test('rejects past, incomplete, and out-of-range start years', () {
    expect(
      AcademicYearValidation.startYearError('2018', currentYear: currentYear),
      'Start year must be 2026 or later.',
    );
    expect(
      AcademicYearValidation.startYearError('20', currentYear: currentYear),
      'Enter a valid four-digit start year.',
    );
    expect(
      AcademicYearValidation.startYearError('', currentYear: currentYear),
      'Enter a valid four-digit start year.',
    );
    expect(
      AcademicYearValidation.startYearError('9999', currentYear: currentYear),
      'Start year must be 9998 or earlier.',
    );
  });

  test('school year advances in June and remains stable through May', () {
    expect(
      AcademicYearValidation.activeSchoolYear(now: DateTime(2027, 5, 31)),
      '2026-2027',
    );
    expect(
      AcademicYearValidation.activeSchoolYear(now: DateTime(2027, 6, 1)),
      '2027-2028',
    );
  });

  test('identifies only school years before the rollover target', () {
    expect(AcademicYearValidation.isBefore('2025-2026', '2026-2027'), isTrue);
    expect(AcademicYearValidation.isBefore('2026-2027', '2026-2027'), isFalse);
    expect(AcademicYearValidation.isBefore('2027-2028', '2026-2027'), isFalse);
    expect(AcademicYearValidation.isBefore('invalid', '2026-2027'), isFalse);
  });

  test('validates class archive state and school-year relationship', () {
    expect(
      AcademicYearValidation.classArchiveError(
        status: 'active',
        classSchoolYear: '2026-2027',
        activeSchoolYear: '2026-2027',
      ),
      isNull,
    );
    expect(
      AcademicYearValidation.classArchiveError(
        status: 'archived',
        classSchoolYear: '2026-2027',
        activeSchoolYear: '2026-2027',
      ),
      'This class is already archived.',
    );
    expect(
      AcademicYearValidation.classArchiveError(
        status: 'active',
        classSchoolYear: '2028-2029',
        activeSchoolYear: '2027-2028',
      ),
      contains('future school year 2028-2029'),
    );
    expect(
      AcademicYearValidation.classArchiveError(
        status: 'active',
        classSchoolYear: 'unknown',
        activeSchoolYear: '2027-2028',
      ),
      contains('valid school year'),
    );
  });
}
