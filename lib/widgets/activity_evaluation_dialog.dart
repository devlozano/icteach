import 'package:flutter/material.dart';

typedef ActivityEvaluation = ({int difficulty, String comment});

Future<ActivityEvaluation?> showActivityEvaluationDialog(
  BuildContext context,
) => showDialog<ActivityEvaluation>(
  context: context,
  builder: (_) => const ActivityEvaluationDialog(),
);

class ActivityEvaluationDialog extends StatefulWidget {
  const ActivityEvaluationDialog({super.key});

  @override
  State<ActivityEvaluationDialog> createState() =>
      _ActivityEvaluationDialogState();
}

class _ActivityEvaluationDialogState extends State<ActivityEvaluationDialog> {
  final commentController = TextEditingController();
  int difficulty = 3;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Activity evaluation'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How difficult was this activity?'),
          Slider(
            value: difficulty.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$difficulty / 5',
            onChanged: (value) => setState(() => difficulty = value.round()),
          ),
          Text(
            const [
              'Very easy',
              'Easy',
              'Appropriate',
              'Difficult',
              'Very difficult',
            ][difficulty - 1],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('activity-evaluation-comment'),
            controller: commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What should be improved? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          difficulty: difficulty,
          comment: commentController.text.trim(),
        )),
        child: const Text('Submit'),
      ),
    ],
  );
}
