import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/learning_path_service.dart';

/// A name-only class directory without staff editing or contact information.
class ClassmatesPage extends StatefulWidget {
  const ClassmatesPage({
    super.key,
    required this.classId,
    required this.className,
    this.loadNames,
  });
  final String classId, className;
  final Future<List<String>> Function()? loadNames;
  @override
  State<ClassmatesPage> createState() => _ClassmatesPageState();
}

class _ClassmatesPageState extends State<ClassmatesPage> {
  late Future<List<String>> _names = _load();
  Future<List<String>> _load() async {
    if (widget.loadNames != null) return widget.loadNames!();
    await LearningPathService.requireActive(widget.classId);
    final db = FirebaseFirestore.instance;
    final classroom = (await db.collection('classes').doc(widget.classId).get())
        .data();
    final ids = List<String>.from(
      classroom?['enrolledStudentIds'] ?? [],
    ).toSet().toList();
    final names = <String>[];
    for (var start = 0; start < ids.length; start += 20) {
      final batch = ids.skip(start).take(20);
      final students = await Future.wait(
        batch.map((id) => db.collection('users').doc(id).get()),
      );
      for (final doc in students) {
        final data = doc.data();
        if (data?['role'] != 'student') continue;
        final parts = [
          data?['firstName'],
          data?['lastName'],
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
        final name = (data?['name'] ?? data?['displayName'] ?? parts)
            .toString()
            .trim();
        names.add(name.isEmpty ? 'Student' : name);
      }
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Classmates - ' + widget.className)),
    body: FutureBuilder<List<String>>(
      future: _names,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load classmates.'),
                TextButton(
                  onPressed: () => setState(() {
                    _names = _load();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty)
          return const Center(child: Text('No classmates enrolled yet.'));
        return ListView(
          children: [
            for (final name in snapshot.data!)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(name),
              ),
          ],
        );
      },
    ),
  );
}
