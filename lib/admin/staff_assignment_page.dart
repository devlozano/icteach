import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/principal_assignments.dart';
import 'staff_assignment_fields.dart';
import '../widgets/principal_workspace_shell.dart';

class StaffAssignmentPage extends StatefulWidget {
  final String uid, role, name;
  const StaffAssignmentPage({
    super.key,
    required this.uid,
    required this.role,
    required this.name,
  });
  @override
  State<StaffAssignmentPage> createState() => _StaffAssignmentPageState();
}

class _StaffAssignmentPageState extends State<StaffAssignmentPage> {
  final _form = GlobalKey<FormState>();
  final _draft = StaffAssignmentDraft();
  bool _busy = false;
  late final Future<void> _initialAssignments = _loadInitialAssignments();

  Future<void> _loadInitialAssignments() async {
    if (widget.role != 'trainer') return;
    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('trainerIds', arrayContains: widget.uid)
        .get();
    final active = snapshot.docs
        .where((doc) => doc.data()['status'] != 'archived')
        .toList();
    if (active.isEmpty) return;
    _draft.teacherId = active.first.data()['teacherId']?.toString();
    _draft.classIds.addAll(
      active
          .where(
            (doc) => doc.data()['teacherId']?.toString() == _draft.teacherId,
          )
          .map((doc) => doc.id),
    );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await PrincipalAssignments().save(widget.uid, widget.role, _draft);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assignments saved.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not save assignments. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PrincipalDetailScaffold(
    title: widget.role == 'teacher' ? 'Add sections' : 'Assign trainer',
    subtitle: widget.role == 'teacher'
        ? 'Create new classes and sections for this teacher.'
        : 'Choose the teacher and classes this trainer will support.',
    icon: widget.role == 'teacher'
        ? Icons.add_home_work_rounded
        : Icons.assignment_ind_rounded,
    maxWidth: 900,
    child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDCE4EC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE2F7F9),
                    foregroundColor: Color(0xFF0891B2),
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          widget.role == 'teacher' ? 'Teacher' : 'Trainer',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.role == 'teacher'
                    ? FirebaseFirestore.instance
                          .collection('classes')
                          .where('teacherId', isEqualTo: widget.uid)
                          .snapshots()
                    : FirebaseFirestore.instance
                          .collection('classes')
                          .where('trainerIds', arrayContains: widget.uid)
                          .snapshots(),
                builder: (_, snapshot) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current classes (${snapshot.data?.docs.where((d) => d.data()['status'] != 'archived').length ?? 0})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LinearProgressIndicator()
                      else if (snapshot.data?.docs.isEmpty ?? true)
                        const Text(
                          'No classes assigned yet.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in snapshot.data!.docs)
                              Chip(
                                avatar: Icon(
                                  c.data()['status'] == 'archived'
                                      ? Icons.archive_outlined
                                      : Icons.class_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  '${c.data()['name']} - ${c.data()['sectionCode'] ?? ''}${c.data()['status'] == 'archived' ? ' (archived)' : ''}',
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              FutureBuilder<void>(
                future: _initialAssignments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'Unable to load current assignments. Reopen this page to retry.',
                    );
                  }
                  return StaffAssignmentFields(
                    role: widget.role,
                    draft: _draft,
                    enabled: !_busy,
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_busy ? 'Saving...' : 'Save assignments'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
