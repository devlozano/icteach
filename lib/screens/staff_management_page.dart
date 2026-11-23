import '../services/workspace_data.dart';
import '../widgets/staff_collection_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../class_roster.dart';
import '../class_detail_page.dart';
import '../widgets/archived_class_badge.dart';
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
        final classes = [...snapshot.data!]
          ..sort((a, b) {
            final aArchived = isArchivedClass(a.data());
            final bArchived = isArchivedClass(b.data());
            if (aArchived != bArchived) return aArchived ? 1 : -1;
            return _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
          });
        final activeCount = classes
            .where((item) => !isArchivedClass(item.data()))
            .length;
        final archivedCount = classes.length - activeCount;
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
              stats: [
                ('Active classes', '$activeCount'),
                ('Archived', '$archivedCount'),
              ],
            ),
            const SizedBox(height: 20),
            CollectionSearch(
              hint: 'Find a class',
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            if (widget.trainer)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Your teacher and classes are assigned by the principal.',
                ),
              ),
            if (visible.isEmpty)
              CollectionEmpty(
                title: classes.isEmpty
                    ? 'No classes yet'
                    : 'No matching classes',
                message: classes.isEmpty
                    ? (widget.trainer
                          ? 'Ask the principal to assign a class to get started.'
                          : 'Ask the principal to assign your sections.')
                    : 'Try another class name.',
                icon: Icons.class_outlined,
              ),
            for (final c in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: isArchivedClass(c.data())
                      ? const Color(0xFFF8FAFC)
                      : Colors.white,
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
                        color: isArchivedClass(c.data())
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFEAF2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isArchivedClass(c.data())
                            ? Icons.archive_outlined
                            : widget.modules
                            ? Icons.menu_book_outlined
                            : Icons.groups_outlined,
                        color: isArchivedClass(c.data())
                            ? const Color(0xFF64748B)
                            : staffBlue,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _name(c),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isArchivedClass(c.data())
                                  ? const Color(0xFF475569)
                                  : staffNavy,
                            ),
                          ),
                        ),
                        if (isArchivedClass(c.data()))
                          const ArchivedClassBadge(),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        isArchivedClass(c.data())
                            ? 'Archived | ${classSchoolYear(c.data())} | Records only'
                            : widget.modules
                            ? 'Open learning modules | ${classSchoolYear(c.data())}'
                            : 'View students and trainers | ${classSchoolYear(c.data())}',
                      ),
                    ),
                    trailing: Icon(
                      isArchivedClass(c.data())
                          ? Icons.lock_outline
                          : Icons.chevron_right,
                      color: isArchivedClass(c.data())
                          ? const Color(0xFF64748B)
                          : staffBlue,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => isArchivedClass(c.data())
                            ? ClassDetailPage(
                                classId: c.id,
                                className: _name(c),
                              )
                            : widget.modules
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
