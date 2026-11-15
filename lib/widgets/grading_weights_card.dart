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
            'ICTeach grading weights',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Quiz 20% • Simulation 65% • Assignment 15%'),
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
                      Text('Quiz ${weights.quiz}%'),
                      Text('Simulation ${weights.simulation}%'),
                      Text('Assignment ${weights.assignment}%'),
                    ],
                  ),
                ],
              ),
            ),
          const Text(
            'Three terms are recorded per school year. Use the Grades tab for term and final grades.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
