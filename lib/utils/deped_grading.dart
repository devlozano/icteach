/// DepEd Order 015, s. 2026, section VI and Annex D (pp. 35–37).
/// https://www.deped.gov.ph/wp-content/uploads/DO_s2026_015r.pdf
enum CssGradingProfile {
  tle('Junior high CSS / TLE', 20, 65),
  techPro('Strengthened SHS CSS / TechPro', 20, 65),
  legacyTvl('Grade 12 TVL (non-strengthened, SY 2026–2027)', 20, 65);

  const CssGradingProfile(
    this.label,
    this.writtenWeight,
    this.performanceWeight,
  );
  final String label;
  final int writtenWeight;
  final int performanceWeight;
}

class GradeScore {
  GradeScore(this.raw, this.maximum) {
    if (!raw.isFinite ||
        !maximum.isFinite ||
        maximum <= 0 ||
        maximum > 1000000 ||
        raw < 0 ||
        raw > maximum) {
      throw ArgumentError('Score must be between zero and a positive maximum.');
    }
  }
  final double raw;
  final double maximum;
  double get percentage => raw / maximum * 100;
  Map<String, dynamic> toMap() => {'raw': raw, 'maximum': maximum};
  factory GradeScore.fromMap(Map<String, dynamic> data) => GradeScore(
    (data['raw'] as num).toDouble(),
    (data['maximum'] as num).toDouble(),
  );
}

class DepEdTermResult {
  const DepEdTermResult(
    this.quiz,
    this.simulation,
    this.assignment,
    this.grade,
  );
  final double quiz, simulation, assignment;
  double get written => quiz;
  double get performance => simulation;
  double get exams => assignment;
  final int grade;
  double get initial => quiz + simulation + assignment;
}

class DepEdGrading {
  static const List<String> periodLabels = <String>[
    'Prelim',
    'Midterm',
    'Final',
  ];

  static String periodLabel(int period) {
    if (period < 1 || period > periodLabels.length) {
      throw ArgumentError.value(period, 'period', 'must be from 1 to 3');
    }
    return periodLabels[period - 1];
  }

  static const components = ['quiz', 'simulation', 'assignment'];
  static const labels = ['Quiz', 'Simulation', 'Assignment'];

  // Explicit lower bounds preserve the published table's irregular intervals.
  static const lowerBounds = <double>[
    0,
    4.68,
    9.35,
    14.01,
    18.68,
    23.35,
    28.01,
    32.68,
    37.34,
    42.01,
    46.67,
    51.34,
    56.01,
    60.67,
    65.34,
    70,
    71.18,
    72.36,
    73.54,
    74.72,
    75.90,
    77.08,
    78.26,
    79.44,
    80.62,
    81.80,
    82.98,
    84.16,
    85.34,
    86.52,
    87.70,
    88.88,
    90.06,
    91.24,
    92.42,
    93.60,
    94.78,
    95.96,
    97.14,
    98.32,
    99.50,
  ];

  static int transmute(double initial) {
    if (!initial.isFinite || initial < 0 || initial > 100) {
      throw ArgumentError('Initial grade must be between 0 and 100.');
    }
    // Compare unrounded scores against lower bounds; do not promote a score
    // below a passing boundary through intermediate display rounding.
    for (var i = lowerBounds.length - 1; i >= 0; i--) {
      if (initial + 1e-10 >= lowerBounds[i]) return 60 + i;
    }
    return 60;
  }

  static DepEdTermResult? calculate(
    Map<String, GradeScore> scores,
    CssGradingProfile profile,
    int schoolYearStart,
  ) {
    if (schoolYearStart < 2026 ||
        (profile == CssGradingProfile.legacyTvl && schoolYearStart != 2026)) {
      throw ArgumentError('Unsupported school year for this grading profile.');
    }
    final hasCurrent = components.every(scores.containsKey);
    final hasLegacy = [
      'ww',
      'pt',
      'st1',
      'st2',
      'te',
    ].every(scores.containsKey);
    if (!hasCurrent && !hasLegacy) return null;
    final quizScore = scores[hasCurrent ? 'quiz' : 'ww']!.percentage;
    final simulationScore =
        scores[hasCurrent ? 'simulation' : 'pt']!.percentage;
    final assignmentScore = hasCurrent
        ? scores['assignment']!.percentage
        : scores['st1']!.percentage * .30 +
              scores['st2']!.percentage * .30 +
              scores['te']!.percentage * .40;
    final quiz = quizScore * .20;
    final simulation = simulationScore * .65;
    final assignment = assignmentScore * .15;
    final initial = (quiz + simulation + assignment).clamp(0.0, 100.0);
    return DepEdTermResult(
      quiz,
      simulation,
      assignment,
      schoolYearStart == 2026 ? transmute(initial) : initial.round(),
    );
  }

  static int? finalGrade(List<int?> terms) {
    if (terms.length != 3 || terms.any((grade) => grade == null)) return null;
    if (terms.any((grade) => grade! < 0 || grade > 100)) {
      throw ArgumentError('Invalid term grade.');
    }
    return (terms.cast<int>().reduce((a, b) => a + b) / 3).round();
  }

  static String remark(List<int?> terms) {
    final grade = finalGrade(terms);
    if (grade == null) return 'Incomplete';
    return grade >= 75 ? 'Passed' : 'Failed';
  }

  static String descriptor(int grade) => grade >= 90
      ? 'Advancing'
      : grade >= 80
      ? 'Proficient'
      : grade >= 75
      ? 'Connecting'
      : grade >= 65
      ? 'Developing'
      : 'Emerging';
}
