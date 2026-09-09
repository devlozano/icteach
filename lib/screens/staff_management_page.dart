import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../class_roster.dart';
import 'teacher/manage_modules_page.dart';

class StaffManagementPage extends StatelessWidget {
  final bool modules, trainer;
  const StaffManagementPage({
    super.key,
    this.modules = false,
    this.trainer = false,
  });
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (!trainer)
      return _classes(
        FirebaseFirestore.instance
            .collection('classes')
            .where('teacherId', isEqualTo: uid)
            .snapshots(),
      );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('classes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Could not load assigned classes.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return _classes(
          FirebaseFirestore.instance.collection('classes').snapshots(),
          ids: snapshot.data!.docs
              .map((d) => d.data()['classId']?.toString() ?? d.id)
              .toSet(),
        );
      },
    );
  }

  Widget _classes(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream, {
    Set<String>? ids,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Center(child: Text('Could not load class management.'));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final classes = snapshot.data!.docs
          .where((d) => ids == null || ids.contains(d.id))
          .toList();
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            modules ? 'Module Management' : 'Student Management',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            modules
                ? 'Choose a class to create, edit, publish, and monitor module access and downloads.'
                : 'Choose a class to view and manage enrolled students.',
          ),
          const SizedBox(height: 20),
          if (classes.isEmpty) const Text('No assigned classes yet.'),
          for (final c in classes)
            Card(
              child: ListTile(
                leading: Icon(
                  modules ? Icons.menu_book_outlined : Icons.groups_outlined,
                ),
                title: Text(
                  c.data()['name']?.toString() ??
                      c.data()['className']?.toString() ??
                      'Class',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => modules
                        ? ManageModulesPage(
                            classId: c.id,
                            className: c.data()['name']?.toString() ?? 'Class',
                          )
                        : ClassRosterPage(
                            classId: c.id,
                            className: c.data()['name']?.toString() ?? 'Class',
                          ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
