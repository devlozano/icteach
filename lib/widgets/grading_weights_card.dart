import 'package:flutter/material.dart';

class GradingWeightsCard extends StatelessWidget {
  const GradingWeightsCard({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grading weights',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Written Works ? 25%'),
          Text('Performance Tasks ? 50%'),
          Text('Quarterly Assessment ? 25%'),
          SizedBox(height: 8),
          Text(
            'Activity averages below are progress indicators, not quarterly grades.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
