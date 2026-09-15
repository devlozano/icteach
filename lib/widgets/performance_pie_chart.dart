import 'dart:math' as math;
import 'package:flutter/material.dart';

class PerformancePieChart extends StatelessWidget {
  const PerformancePieChart({super.key, required this.entries});
  final List<Map<String, dynamic>> entries;
  static const labels = ['90-100%', '75-89%', 'Below 75%'];
  static const colors = [
    Color(0xFF0891B2),
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
  ];
  static List<int> countsFor(List<Map<String, dynamic>> entries) {
    final counts = [0, 0, 0];
    for (final entry in entries) {
      final score = entry['percentage'];
      if (score is! num || !score.isFinite || score < 0 || score > 100)
        continue;
      counts[score >= 90
          ? 0
          : score >= 75
          ? 1
          : 2]++;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = countsFor(entries);
    final total = counts.fold(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student quiz performance',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              total.toString() +
                  ' students with recorded quiz results, grouped by overall quiz percentage.',
            ),
            const SizedBox(height: 24),
            if (total == 0)
              const Text('No performance data yet.')
            else ...[
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(painter: _PiePainter(counts)),
                ),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < counts.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(width: 14, height: 14, color: colors[i]),
                      const SizedBox(width: 10),
                      Expanded(child: Text(labels[i])),
                      Text(
                        counts[i].toString() +
                            ' (' +
                            (counts[i] / total * 100).toStringAsFixed(1) +
                            '%)',
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.counts);
  final List<int> counts;
  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.fold(0, (a, b) => a + b);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < counts.length; i++) {
      final sweep = counts[i] / total * 2 * math.pi;
      canvas.drawArc(
        Offset.zero & size,
        start,
        sweep,
        true,
        Paint()..color = PerformancePieChart.colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => List.generate(
    counts.length,
    (i) => counts[i] != oldDelegate.counts[i],
  ).any((v) => v);
}
