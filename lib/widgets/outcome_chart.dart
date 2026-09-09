import 'package:flutter/material.dart';

class OutcomeChart extends StatelessWidget {
  final String title;
  final Map<String, int> values;
  const OutcomeChart({super.key, required this.title, required this.values});
  @override
  Widget build(BuildContext context) {
    final total = values.values.fold(0, (a, b) => a + b);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            for (final entry in values.entries) ...[
              Text('${entry.key}: ${entry.value}'),
              const SizedBox(height: 8),
              Semantics(
                label: '${entry.key}, ${entry.value} of $total',
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : entry.value / total,
                  minHeight: 16,
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF0891B2),
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (total == 0) const Text('No responses or records yet.'),
          ],
        ),
      ),
    );
  }
}
