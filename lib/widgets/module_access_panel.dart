import 'module_access_overview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/module_access_service.dart';
import 'summary_print_button.dart';

class ModuleAccessPanel extends StatelessWidget {
  final String classId, moduleId, title;
  const ModuleAccessPanel({
    super.key,
    this.initiallyExpanded = false,
    required this.classId,
    required this.moduleId,
    required this.title,
  });
  final bool initiallyExpanded;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .snapshots(),
    builder: (context, classroom) {
      if (classroom.hasError)
        return const Text('Unable to load module enrollment.');
      if (!classroom.hasData) return const LinearProgressIndicator();
      final ids = Set<String>.from(
        classroom.data!.data()?['enrolledStudentIds'] ?? [],
      );
      return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: Future.wait(
          ids.map(
            (id) =>
                FirebaseFirestore.instance.collection('users').doc(id).get(),
          ),
        ),
        builder: (context, profiles) {
          if (profiles.hasError) return const Text('Unable to load students.');
          if (!profiles.hasData) return const LinearProgressIndicator();
          final students = profiles.data!
              .where((d) => d.data()?['role'] == 'student')
              .toList();
          final studentIds = students.map((d) => d.id).toSet();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('classes')
                .doc(classId)
                .collection('module_access')
                .where('moduleId', isEqualTo: moduleId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Text('Unable to load module access.');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final records = snapshot.data!.docs.map((d) => d.data()).toList();
              final summary = ModuleAccessSummary.fromRecords(
                records,
                studentIds,
              );
              final byId = {for (final r in records) r['studentId']: r};
              final rows = [
                for (final student in students)
                  <Object?>[
                    student.data()?['name'] ??
                        student.data()?['email'] ??
                        student.id,
                    byId[student.id]?['accessed'] == true
                        ? 'Accessed'
                        : 'Not accessed',
                    byId[student.id]?['downloaded'] == true
                        ? 'Downloaded'
                        : byId[student.id]?['downloadRequested'] == true
                        ? 'Browser request (unconfirmed)'
                        : 'Not downloaded',
                  ],
              ];
              return ModuleAccessOverview(
                initiallyExpanded: initiallyExpanded,
                accessed: summary.accessed,
                downloaded: summary.downloaded,
                requested: summary.requested,
                students: [
                  for (final student in students)
                    ModuleStudentActivity(
                      id: student.id,
                      name:
                          (student.data()?['name'] ??
                                  student.data()?['email'] ??
                                  student.id)
                              .toString(),
                      accessed: byId[student.id]?['accessed'] == true,
                      downloaded: byId[student.id]?['downloaded'] == true,
                      requested: byId[student.id]?['downloadRequested'] == true,
                    ),
                ],
                printAction: SummaryPrintButton(
                  title: 'Module access - $title',
                  load: () async => [
                    SummarySection(
                      'Module totals',
                      ['Students', 'Accessed', 'Downloaded', 'Requests'],
                      [
                        [
                          students.length,
                          summary.accessed,
                          summary.downloaded,
                          summary.requested,
                        ],
                      ],
                    ),
                    SummarySection('Student access and downloads', [
                      'Student',
                      'Lesson access',
                      'Download status',
                    ], rows),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
