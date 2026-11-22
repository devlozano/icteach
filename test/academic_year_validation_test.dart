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
}
