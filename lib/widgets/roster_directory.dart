import 'package:flutter/material.dart';
import 'staff_collection_ui.dart';

class RosterDirectory extends StatefulWidget {
  const RosterDirectory({
    super.key,
    required this.students,
    required this.trainers,
    required this.itemBuilder,
  });
  final List<Map<String, dynamic>> students, trainers;
  final Widget Function(Map<String, dynamic> user, bool trainer) itemBuilder;
  @override
  State<RosterDirectory> createState() => _RosterDirectoryState();
}

class _RosterDirectoryState extends State<RosterDirectory> {
  String _query = '';
  String _role = 'All';
  @override
  Widget build(BuildContext context) {
    final people =
        [
              if (_role != 'Trainers')
                ...widget.students.map((s) => (s, false)),
              if (_role != 'Students') ...widget.trainers.map((s) => (s, true)),
            ]
            .where(
              (p) => '${p.$1['name']} ${p.$1['email']}'.toLowerCase().contains(
                _query,
              ),
            )
            .toList()
          ..sort(
            (a, b) => '${a.$1['name']}'.toLowerCase().compareTo(
              '${b.$1['name']}'.toLowerCase(),
            ),
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CollectionOverview(
                  title: 'Class directory',
                  description:
                      'Find students and trainers enrolled in this class.',
                  icon: Icons.groups_outlined,
                  stats: [
                    ('Students', '${widget.students.length}'),
                    ('Trainers', '${widget.trainers.length}'),
                  ],
                ),
                const SizedBox(height: 22),
                CollectionSearch(
                  hint: 'Search by name or email',
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in ['All', 'Students', 'Trainers'])
                      ChoiceChip(
                        label: Text(role),
                        selected: _role == role,
                        onSelected: (_) => setState(() => _role = role),
                        selectedColor: const Color(0xFFDCEBFC),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${people.length} ${people.length == 1 ? 'person' : 'people'} shown',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (people.isEmpty)
                  CollectionEmpty(
                    title: widget.students.isEmpty && widget.trainers.isEmpty
                        ? 'Your class is ready for students'
                        : 'No matching people',
                    message: widget.students.isEmpty && widget.trainers.isEmpty
                        ? 'Share the class code or QR code to invite your class.'
                        : 'Try another name, email, or role filter.',
                    icon: Icons.people_outline,
                  ),
                for (final person in people)
                  KeyedSubtree(
                    key: ValueKey('${person.$2}/${person.$1['id']}'),
                    child: widget.itemBuilder(person.$1, person.$2),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
