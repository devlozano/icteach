import 'package:flutter/material.dart';
import '../data/grading_weights.dart';

class GradingWeightsCard extends StatelessWidget {
  const GradingWeightsCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grading weights by subject',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'WWs: Written Works • PTs: Performance Tasks\nSTs–TE: Summative Tests & Term Exams',
          ),
          const SizedBox(height: 16),
          for (final weights in GradingWeights.subjectGroups)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weights.subjectGroup,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 20,
                    runSpacing: 4,
                    children: [
                      Text('WWs ${weights.writtenWorks}%'),
                      Text('PTs ${weights.performanceTasks}%'),
                      Text(
                        weights.summativeTestsTermExams == 0
                            ? 'STs–TE —'
                            : 'STs–TE ${weights.summativeTestsTermExams}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Text(
            '— means no STs–TE component. Activity averages below are progress indicators, not quarterly grades.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
