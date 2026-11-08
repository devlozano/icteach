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
  test(
    'TLE and TechPro use different component weights with 30/30/40 exams',
    () {
      final scores = {
        'ww': GradeScore(40, 50),
        'pt': GradeScore(90, 100),
        'st1': GradeScore(10, 20),
        'st2': GradeScore(30, 40),
        'te': GradeScore(60, 100),
      };
      final tle = DepEdGrading.calculate(scores, CssGradingProfile.tle, 2026)!;
      expect(tle.exams, closeTo(12.3, .00001));
      expect(tle.initial, closeTo(82.3, .00001));
      expect(tle.grade, 85);
      final shs = DepEdGrading.calculate(
        scores,
        CssGradingProfile.techPro,
        2026,
      )!;
      expect(shs.initial, closeTo(82.8, .00001));
      expect(shs.grade, 85);
    },
  );
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
