import 'package:flutter/material.dart';

bool isArchivedClass(Map<String, dynamic> data) =>
    data['status']?.toString().toLowerCase() == 'archived';

String classSchoolYear(Map<String, dynamic> data) {
  final value = data['schoolYear']?.toString().trim() ?? '';
  return value.isEmpty ? 'School year unavailable' : value;
}

class ArchivedClassBadge extends StatelessWidget {
  const ArchivedClassBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: const Text(
        'ARCHIVED',
        style: TextStyle(
          color: Color(0xFF9A3412),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
