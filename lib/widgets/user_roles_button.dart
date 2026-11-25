import 'package:flutter/material.dart';

class UserRolesButton extends StatelessWidget {
  const UserRolesButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'System user roles',
    icon: const Icon(Icons.help_outline),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Who does what in ICTeach?'),
        content: const SingleChildScrollView(
          child: Text(
            'Administrator\nManages staff accounts, LRN records, school years and class archives.\n\n'
            'Teacher / Adviser\nCreates classes and lessons, authors quizzes and assignments, links lessons to fixed simulations, grades work and monitors learners.\n\n'
            'Trainer\nJoins assigned classes, supports practical instruction, manages learning content and quizzes, reviews student difficulties and observes competency evidence.\n\n'
            'Student\nStudies lessons, practices before assignments, takes theory quizzes and interactive simulations, submits work and provides teaching/system feedback.\n\n'
            'Simulation scores support learning. Only supervised practical observation can validate hands-on performance; ICTeach does not issue TESDA certification.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    ),
  );
}
