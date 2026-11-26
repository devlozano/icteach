import 'package:flutter/material.dart';
import '../../models/quiz_model.dart';
import '../../services/quiz_service.dart';

class TeacherQuizResultsPage extends StatefulWidget {
  final String classId;
  final String quizId;
  final String quizTitle;

  const TeacherQuizResultsPage({
    super.key,
    required this.classId,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<TeacherQuizResultsPage> createState() => _TeacherQuizResultsPageState();
}

class _TeacherQuizResultsPageState extends State<TeacherQuizResultsPage> {
  final QuizService _quizService = QuizService();

  Future<void> _allowRetry(QuizResult result) async {
    final controller = TextEditingController();
    final feedback = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feedback before retry'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'What should the student review?',
            hintText: 'Explain the skill or lesson that needs improvement.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Allow retry'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (feedback == null || !mounted) return;
    try {
      await _quizService.allowQuizRetry(result, feedback);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry opened for ${result.studentName}.')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open retry: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text('Results: ${widget.quizTitle}'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // Refresh results
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<QuizResult>>(
        future: _quizService.getQuizResults(widget.classId, widget.quizId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final results = snapshot.data ?? [];

          if (results.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No submissions yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Students haven\'t taken this quiz yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Calculate statistics
          final totalStudents = results.length;
          final averageScore =
              results.fold<double>(0, (sum, r) => sum + r.percentage) /
              totalStudents;
          final passedCount = results.where((r) => r.isPassed).length;
          final highestScore = results
              .map((r) => r.percentage)
              .reduce((a, b) => a > b ? a : b);
          final lowestScore = results
              .map((r) => r.percentage)
              .reduce((a, b) => a < b ? a : b);

          return Column(
            children: [
              // Statistics Card
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Students',
                          value: '$totalStudents',
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                        _StatItem(
                          label: 'Average',
                          value: '${averageScore.toStringAsFixed(1)}%',
                          icon: Icons.analytics,
                          color: Colors.purple,
                        ),
                        _StatItem(
                          label: 'Passed',
                          value: '$passedCount/$totalStudents',
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Highest',
                          value: '${highestScore.toStringAsFixed(0)}%',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                        _StatItem(
                          label: 'Lowest',
                          value: '${lowestScore.toStringAsFixed(0)}%',
                          icon: Icons.trending_down,
                          color: Colors.red,
                        ),
                        _StatItem(
                          label: 'Pass Rate',
                          value:
                              '${((passedCount / totalStudents) * 100).toStringAsFixed(0)}%',
                          icon: Icons.emoji_events,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Results List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return _ResultCard(
                      result: result,
                      onAllowRetry: () => _allowRetry(result),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Statistics Item
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// Result Card
class _ResultCard extends StatelessWidget {
  final QuizResult result;
  final VoidCallback onAllowRetry;

  const _ResultCard({required this.result, required this.onAllowRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result.isPassed ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: result.isPassed
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Text(
                  result.studentName.isNotEmpty
                      ? result.studentName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: result.isPassed
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text(
                          'Score: ${result.score}/${result.totalPoints}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${result.percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: result.isPassed
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '⏱ ${_formatTime(result.timeSpent)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: result.isPassed
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.isPassed ? 'Passed' : 'Failed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: result.isPassed
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (!result.isPassed) ...[
            const SizedBox(height: 10),
            if (result.teacherFeedback.isNotEmpty)
              Text(
                'Feedback: ${result.teacherFeedback}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: result.retryAllowed ? null : onAllowRetry,
                icon: Icon(result.retryAllowed ? Icons.schedule : Icons.replay),
                label: Text(
                  result.retryAllowed
                      ? 'Retry opened'
                      : 'Give feedback & allow retry',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
