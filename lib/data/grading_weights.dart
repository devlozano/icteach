/// ICTeach assessment weights used consistently across reports and gradebooks.
class GradingWeights {
  const GradingWeights(
    this.subjectGroup,
    this.quiz,
    this.simulation,
    this.assignment,
  );
  final String subjectGroup;
  final int quiz, simulation, assignment;

  static const subjectGroups = <GradingWeights>[
    GradingWeights('Computer Systems Servicing', 20, 65, 15),
  ];
}
