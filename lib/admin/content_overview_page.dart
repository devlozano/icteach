import '../services/workspace_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/teacher/manage_modules_page.dart';
import '../screens/teacher/manage_quizzes_page.dart';
import '../screens/teacher/manage_assignments_page.dart';
import '../screens/teacher/content_lock_manager.dart';

class ContentOverviewPage extends StatelessWidget {
  const ContentOverviewPage({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: WorkspaceData.watch(
      'adminClasses',
      () => FirebaseFirestore.instance.collection('classes').snapshots(),
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('Content overview could not be loaded.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data!.docs.isEmpty) {
        return const Center(child: Text('No classes yet.'));
      }
      return ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Content overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (final classroom in snapshot.data!.docs)
            Card(
              child: ExpansionTile(
                title: Text(
                  (classroom.data()['className'] ??
                          classroom.data()['name'] ??
                          'Class')
                      .toString(),
                ),
                children: [
                  for (final kind in ['modules', 'quizzes', 'assignments'])
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: WorkspaceData.watch(
                        'classContent/' + classroom.id + '/' + kind,
                        () => classroom.reference.collection(kind).snapshots(),
                      ),
                      builder: (context, content) => ListTile(
                        title: Text(kind[0].toUpperCase() + kind.substring(1)),
                        subtitle: Text(
                          content.hasError
                              ? 'Unable to load counts'
                              : !content.hasData
                              ? 'Loading...'
                              : '${content.data!.docs.length} total / ${content.data!.docs.where((d) => d.data()['isPublished'] == true).length} published',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final name =
                              (classroom.data()['className'] ??
                                      classroom.data()['name'] ??
                                      'Class')
                                  .toString();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => switch (kind) {
                                'modules' => ManageModulesPage(
                                  classId: classroom.id,
                                  className: name,
                                ),
                                'quizzes' => ManageQuizzesPage(
                                  classId: classroom.id,
                                  className: name,
                                ),
                                _ => ManageAssignmentsPage(
                                  classId: classroom.id,
                                  className: name,
                                ),
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ListTile(
                    title: const Text('Content access'),
                    trailing: const Icon(Icons.lock_outline),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ContentLockManager(classId: classroom.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
