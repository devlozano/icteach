import 'package:flutter/material.dart';

class WorkspaceIntro extends StatelessWidget {
  final String title, description;
  const WorkspaceIntro({
    super.key,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF164E63)],
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ICTEACH WORKSPACE',
          style: TextStyle(
            color: Color(0xFF67E8F9),
            letterSpacing: 2,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
