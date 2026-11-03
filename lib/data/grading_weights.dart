/// Subject weights from the reference supplied for ICTeach.
class GradingWeights {
  const GradingWeights(
    this.subjectGroup,
    this.writtenWorks,
    this.performanceTasks,
    this.summativeTestsTermExams,
  );
  final String subjectGroup;
  final int writtenWorks, performanceTasks, summativeTestsTermExams;

  static const subjectGroups = <GradingWeights>[
    GradingWeights(
      'AP, English, Filipino, Mathematics, Science, GMRC / Values Education',
      20,
      50,
      30,
    ),
    GradingWeights('EPP / TLE and MAPEH', 20, 60, 20),
    GradingWeights(
      'SHS Core Subjects and Other SHS Academic Electives',
      20,
      50,
      30,
    ),
    GradingWeights(
      'SHS Field Exposure, Arts Apprenticeship, Creative Production and Innovation',
      15,
      70,
      15,
    ),
    GradingWeights(
      'SHS Arts, Sports, Health and Wellness Electives',
      20,
      60,
      20,
    ),
    GradingWeights(
      'SHS Research Electives and Design and Innovation',
      40,
      60,
      0,
    ),
    GradingWeights('SHS TechPro Electives', 15, 65, 20),
    GradingWeights('SHS Work Immersion', 20, 80, 0),
  ];
}
