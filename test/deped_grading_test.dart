import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/utils/deped_grading.dart';

void main() {
  Map<String, GradeScore> uniform(double score) => {
    for (final key in DepEdGrading.components) key: GradeScore(score, 100),
  };
  test('Every official transmutation boundary and value just below it', () {
    for (var i = 0; i < DepEdGrading.lowerBounds.length; i++) {
      final bound = DepEdGrading.lowerBounds[i];
      expect(DepEdGrading.transmute(bound), 60 + i);
      if (i > 0) expect(DepEdGrading.transmute(bound - .001), 59 + i);
    }
    expect(DepEdGrading.transmute(100), 100);
    expect(DepEdGrading.transmute(69.999), 74);
  });
  test('Quiz, simulation, and assignment use 20/65/15 weights', () {
    final scores = {
      'quiz': GradeScore(80, 100),
      'simulation': GradeScore(90, 100),
      'assignment': GradeScore(60, 100),
    };
    final result = DepEdGrading.calculate(
      scores,
      CssGradingProfile.techPro,
      2026,
    )!;
    expect(result.quiz, 16);
    expect(result.simulation, 58.5);
    expect(result.assignment, 9);
    expect(result.initial, 83.5);
    expect(result.grade, 86);
  });

  test('Archived five-component records remain readable with new weights', () {
    final result = DepEdGrading.calculate(
      {
        'ww': GradeScore(80, 100),
        'pt': GradeScore(90, 100),
        'st1': GradeScore(60, 100),
        'st2': GradeScore(60, 100),
        'te': GradeScore(60, 100),
      },
      CssGradingProfile.techPro,
      2026,
    )!;
    expect(result.initial, 83.5);
  });
  test('Missing scores remain incomplete while zero is a real score', () {
    expect(DepEdGrading.calculate({}, CssGradingProfile.tle, 2026), isNull);
    expect(
      DepEdGrading.calculate(uniform(0), CssGradingProfile.tle, 2026)!.grade,
      60,
    );
    expect(
      DepEdGrading.calculate(uniform(70), CssGradingProfile.tle, 2026)!.grade,
      75,
    );
    expect(
      DepEdGrading.calculate(uniform(70), CssGradingProfile.tle, 2027)!.grade,
      70,
    );
  });
  test('Final grade requires exactly three completed terms', () {
    expect(DepEdGrading.finalGrade([75, 80, 90]), 82);
    expect(DepEdGrading.finalGrade([75, null, 90]), isNull);
    expect(DepEdGrading.finalGrade([75, 80, 90, 95]), isNull);
  });
  test('Workbook periods and remarks are consistent', () {
    expect(
      [
        for (var period = 1; period <= 3; period++)
          DepEdGrading.periodLabel(period),
      ],
      ['Prelim', 'Midterm', 'Final'],
    );
    expect(DepEdGrading.remark([75, 80, 90]), 'Passed');
    expect(DepEdGrading.remark([74, 74, 74]), 'Failed');
    expect(DepEdGrading.remark([75, null, 90]), 'Incomplete');
  });
  test('Invalid score and policy inputs are rejected', () {
    for (final pair in [
      [-1.0, 10.0],
      [11.0, 10.0],
      [0.0, 0.0],
      [double.nan, 100.0],
    ]) {
      expect(() => GradeScore(pair[0], pair[1]), throwsArgumentError);
    }
    expect(
      () => DepEdGrading.calculate(uniform(80), CssGradingProfile.tle, 2025),
      throwsArgumentError,
    );
    expect(
      () => DepEdGrading.calculate(
        uniform(80),
        CssGradingProfile.legacyTvl,
        2027,
      ),
      throwsArgumentError,
    );
  });
}
