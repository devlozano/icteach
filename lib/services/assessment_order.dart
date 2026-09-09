import 'dart:math';

/// Display positions map to original indices; saved answers retain their identity.
class AssessmentOrder {
  final List<int> questions;
  final List<List<int>> options;
  AssessmentOrder(List<int> optionCounts, {Random? random})
    : questions = List.generate(optionCounts.length, (i) => i),
      options = [
        for (final count in optionCounts) List.generate(count, (i) => i),
      ] {
    final source = random ?? Random.secure();
    questions.shuffle(source);
    for (final order in options) {
      order.shuffle(source);
    }
  }
}
