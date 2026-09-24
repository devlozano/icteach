import '../join_class.dart';
import '../services/workspace_data.dart';
import '../widgets/staff_collection_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../class_roster.dart';
import 'teacher/manage_modules_page.dart';

class StaffManagementPage extends StatefulWidget {
  final bool modules, trainer, embedded;
  const StaffManagementPage({
    super.key,
    this.modules = false,
    this.trainer = false,
    this.embedded = false,
  });
  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  String _query = '';
  String _name(QueryDocumentSnapshot<Map<String, dynamic>> c) =>
      c.data()['name']?.toString() ??
      c.data()['className']?.toString() ??
      'Class';
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in to view your classes.'));
    }
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: widget.trainer
          ? WorkspaceData.assignedClasses(uid)
          : WorkspaceData.teacherClassDocs(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const CollectionEmpty(
            title: 'Classes could not be loaded',
            message: 'Check your connection and reopen this page.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final classes = snapshot.data!;
        final visible = classes
            .where((c) => _name(c).toLowerCase().contains(_query))
            .toList();
        return ListView(
          shrinkWrap: widget.embedded,
          physics: widget.embedded
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(16),
          children: [
            CollectionOverview(
              title: widget.modules
                  ? 'Module Management'
                  : 'Student Management',
              description: widget.modules
                  ? 'Choose a class to organize lessons and manage learning materials.'
                  : 'Choose a class to find students and manage your roster.',
              icon: widget.modules
                  ? Icons.auto_stories_outlined
                  : Icons.groups_outlined,
              stats: [('Classes', '${classes.length}')],
            ),
            const SizedBox(height: 20),
            CollectionSearch(
              hint: 'Find a class',
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            if (widget.trainer) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinClassPage()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Join class'),
                  style: FilledButton.styleFrom(backgroundColor: staffNavy),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (visible.isEmpty)
              CollectionEmpty(
                title: classes.isEmpty
                    ? 'No classes yet'
                    : 'No matching classes',
                message: classes.isEmpty
                    ? (widget.trainer
                          ? 'Join a class to get started.'
                          : 'Create a class from your dashboard to get started.')
                    : 'Try another class name.',
                icon: Icons.class_outlined,
              ),
            for (final c in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.modules
                            ? Icons.menu_book_outlined
                            : Icons.groups_outlined,
                        color: staffBlue,
                      ),
                    ),
                    title: Text(
                      _name(c),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: staffNavy,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.modules
                            ? 'Open learning modules'
                            : 'View students and trainers',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: staffBlue),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => widget.modules
                            ? ManageModulesPage(
                                classId: c.id,
                                className: _name(c),
                              )
                            : ClassRosterPage(
                                classId: c.id,
                                className: _name(c),
                              ),
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
}
