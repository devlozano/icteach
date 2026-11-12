import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/principal_assignments.dart';

class StaffAssignmentFields extends StatefulWidget {
  final String role;
  final StaffAssignmentDraft draft;
  final bool enabled;
  final FirebaseFirestore? firestore;
  const StaffAssignmentFields({
    super.key,
    required this.role,
    required this.draft,
    this.enabled = true,
    this.firestore,
  });
  @override
  State<StaffAssignmentFields> createState() => _StaffAssignmentFieldsState();
}

class _StaffAssignmentFieldsState extends State<StaffAssignmentFields> {
  FirebaseFirestore get db => widget.firestore ?? FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    if (widget.role == 'teacher') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classes and sections',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'The principal creates each section and assigns it to this teacher.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('section-count'),
            initialValue: '${widget.draft.sections.length}',
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Number of classes to add',
              helperText: '1 to 50 sections per save',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 50 ? 'Enter 1 to 50.' : null;
            },
            onChanged: (value) {
              final n = int.tryParse(value);
              if (n == null || n < 1 || n > 50) return;
              setState(() {
                while (widget.draft.sections.length < n) {
                  widget.draft.sections.add(SectionDraft());
                }
                if (widget.draft.sections.length > n) {
                  widget.draft.sections.removeRange(
                    n,
                    widget.draft.sections.length,
                  );
                }
              });
            },
          ),
          for (var i = 0; i < widget.draft.sections.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  TextFormField(
                    key: ValueKey('class-name-$i'),
                    enabled: widget.enabled,
                    initialValue: widget.draft.sections[i].name,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'Class ${i + 1} name',
                    ),
                    onChanged: (v) => widget.draft.sections[i].name = v,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Class name is required.'
                        : null,
                  ),
                  TextFormField(
                    key: ValueKey('section-name-$i'),
                    enabled: widget.enabled,
                    initialValue: widget.draft.sections[i].section,
                    maxLength: 60,
                    decoration: InputDecoration(labelText: 'Section ${i + 1}'),
                    onChanged: (v) => widget.draft.sections[i].section = v,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Section is required.'
                        : null,
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (widget.role != 'trainer') return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load teachers. Reopen this form to retry.',
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final teachers = snapshot.data!.docs
            .where((d) => d.data()['isActive'] != false)
            .toList();
        final selected = teachers.any((d) => d.id == widget.draft.teacherId)
            ? widget.draft.teacherId
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('assigned-teacher-$selected'),
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Assigned teacher'),
              items: teachers
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        d.data()['name'] ?? d.data()['email'] ?? 'Teacher',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              validator: (v) => v == null ? 'Select a teacher.' : null,
              onChanged: !widget.enabled
                  ? null
                  : (v) => setState(() {
                      widget.draft.teacherId = v;
                      widget.draft.classIds.clear();
                    }),
            ),
            if (teachers.isEmpty) const Text('Add an active teacher first.'),
            if (selected != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('classes')
                    .where('teacherId', isEqualTo: selected)
                    .snapshots(),
                builder: (context, classes) {
                  if (classes.hasError) {
                    return const Text(
                      'Unable to load classes. Select the teacher again to retry.',
                    );
                  }
                  if (!classes.hasData) return const LinearProgressIndicator();
                  final active = classes.data!.docs
                      .where((d) => d.data()['status'] != 'archived')
                      .toList();
                  return FormField<Set<String>>(
                    validator: (_) =>
                        !active.any((d) => widget.draft.classIds.contains(d.id))
                        ? 'Select at least one active class.'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Text('Classes to train'),
                        if (active.isEmpty)
                          const Text(
                            'This teacher has no active sections. Add sections first.',
                          ),
                        for (final c in active)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${c.data()['name']} - ${c.data()['sectionCode'] ?? ''}',
                            ),
                            value: widget.draft.classIds.contains(c.id),
                            onChanged: !widget.enabled
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        widget.draft.classIds.add(c.id);
                                      } else {
                                        widget.draft.classIds.remove(c.id);
                                      }
                                    });
                                    field.didChange(widget.draft.classIds);
                                  },
                          ),
                        if (field.hasError)
                          Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
