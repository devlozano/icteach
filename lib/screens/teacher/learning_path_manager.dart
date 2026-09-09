import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/simulation_data.dart';
import '../../services/content_access_service.dart';
import '../../services/learning_path_service.dart';

class LearningPathManager extends StatefulWidget {
  final String classId;
  const LearningPathManager({super.key, required this.classId});
  @override
  State<LearningPathManager> createState() => _LearningPathManagerState();
}

class _LearningPathManagerState extends State<LearningPathManager> {
  late final Future<bool> _staff = ContentAccessService.isClassStaff(
    widget.classId,
  );
  Future<void> _edit(String type, String id, String title) async {
    try {
      await LearningPathService.requireActive(widget.classId);
      final root = FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId);
      final modules =
          (await root
                  .collection('modules')
                  .where('isPublished', isEqualTo: true)
                  .get())
              .docs;
      final quizzes =
          (await root
                  .collection('quizzes')
                  .where('isPublished', isEqualTo: true)
                  .get())
              .docs
              .where((q) => (q.data()['questions'] as List? ?? []).isNotEmpty)
              .toList();
      final ref = root
          .collection('learning_paths')
          .doc(LearningPathService.key(type, id));
      final old = (await ref.get()).data();
      String? moduleId = old?['moduleId'];
      String? quizId = old?['quizId'];
      if (!modules.any((m) => m.id == moduleId)) moduleId = null;
      if (!quizzes.any((q) => q.id == quizId)) quizId = null;
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Learning path: $title'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Choose the lesson that actually teaches this activity. Students must complete it before practice. Simulation assessment also requires the selected theory quiz. Simulations remain fixed, not editable quiz questions.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: moduleId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Required published module',
                      ),
                      items: modules
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.data()['title'] ?? m.id,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => update(() => moduleId = v),
                    ),
                    if (type == 'simulation')
                      DropdownButtonFormField<String>(
                        initialValue: quizId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Part 1: teacher/trainer theory quiz',
                        ),
                        items: quizzes
                            .map(
                              (q) => DropdownMenuItem(
                                value: q.id,
                                child: Text(
                                  q.data()['title'] ?? q.id,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => update(() => quizId = v),
                      ),
                    if (modules.isEmpty ||
                        (type == 'simulation' && quizzes.isEmpty))
                      const Text(
                        'Publish a module and a nonempty theory quiz first.',
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    moduleId == null || (type == 'simulation' && quizId == null)
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (save != true) return;
      if (!await ContentAccessService.isClassStaff(widget.classId))
        throw StateError('Staff access required.');
      await LearningPathService.requireActive(widget.classId);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(ref, {
        'moduleId': moduleId,
        'quizId': type == 'simulation' ? quizId : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // The same lesson prepares students for the terminology/theory stage.
      if (type == 'simulation' &&
          !(await root.collection('learning_paths').doc('quiz_$quizId').get())
              .exists)
        batch.set(
          root.collection('learning_paths').doc('quiz_$quizId'),
          {'moduleId': moduleId, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      await batch.commit();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save learning path: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lesson & assessment links')),
    body: FutureBuilder<bool>(
      future: _staff,
      builder: (context, staff) {
        if (staff.hasError || staff.data == false)
          return const Center(
            child: Text('Class teacher/trainer access required.'),
          );
        if (!staff.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'To make a simulation available:\n\n1. In Modules, add the lesson, turn on Publish, then choose Upload & Publish Module. A draft will not unlock it.\n\n2. In Quizzes, create and publish a theory quiz with questions.\n\n3. Select the simulation below, choose its published module and Part 1 theory quiz, then Save.\n\n4. In Content Lock Settings, make sure the lesson, quiz and simulation are unlocked. Students must be enrolled in an active class.\n\nStudents complete the lesson, ungraded practice and the theory quiz before the simulation assessment. Any previous simulation requirement must also be passed.',
              ),
            ),
            ...SimulationData.getAllSimulations().map(
              (s) => ListTile(
                leading: const Icon(Icons.science),
                title: Text(s.title),
                subtitle: Text('${s.competency}: ${s.learningOutcome}'),
                trailing: const Icon(Icons.link),
                onTap: () => _edit('simulation', s.id, s.title),
              ),
            ),
            const Divider(),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .doc(widget.classId)
                  .collection('quizzes')
                  .snapshots(),
              builder: (context, snapshot) => Column(
                children: [
                  if (snapshot.hasError) const Text('Unable to load quizzes.'),
                  ...?snapshot.data?.docs.map(
                    (q) => ListTile(
                      leading: const Icon(Icons.quiz),
                      title: Text(q.data()['title'] ?? q.id),
                      subtitle: const Text(
                        'Set the lesson prerequisite for this quiz',
                      ),
                      onTap: () =>
                          _edit('quiz', q.id, q.data()['title'] ?? q.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
