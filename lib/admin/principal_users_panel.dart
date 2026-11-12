import '../create_class.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'create_staff_page.dart';
import 'staff_assignment_page.dart';

class PrincipalUsersPanel extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const PrincipalUsersPanel({super.key, this.firestore});

  @override
  State<PrincipalUsersPanel> createState() => _PrincipalUsersPanelState();
}

class _PrincipalUsersPanelState extends State<PrincipalUsersPanel> {
  static const _navy = Color(0xFF0B2B4A);
  static const _blue = Color(0xFF2F80ED);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  String _role = 'all', _status = 'all', _search = '';
  final _busy = <String>{};

  FirebaseFirestore get db => widget.firestore ?? FirebaseFirestore.instance;

  Future<void> _toggle(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    if (_busy.contains(doc.id)) return;
    setState(() => _busy.add(doc.id));
    try {
      await doc.reference.update({
        'isActive': doc.data()['isActive'] == false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update status. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(doc.id));
    }
  }

  String _name(Map<String, dynamic> data) =>
      (data['name'] ?? data['displayName'] ?? data['email'] ?? 'User')
          .toString();

  Color _roleColor(String role) => switch (role) {
    'teacher' => const Color(0xFF1D4ED8),
    'trainer' => const Color(0xFF7C3AED),
    _ => const Color(0xFF475569),
  };

  Widget _badge({
    required String label,
    required Color color,
    required IconData icon,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _userCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool compact,
  ) {
    final data = doc.data();
    final role = data['role'] as String;
    final active = data['isActive'] != false;
    final name = _name(data);
    final color = _roleColor(role);
    final email = (data['email'] ?? '').toString();
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.isNotEmpty ? part[0] : '')
              .join()
              .toUpperCase();

    final identity = Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Text(
            initials,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final labels = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _badge(
          label: role[0].toUpperCase() + role.substring(1),
          color: color,
          icon: role == 'teacher'
              ? Icons.school_outlined
              : role == 'trainer'
              ? Icons.sports_outlined
              : Icons.person_outline,
        ),
        _badge(
          label: active ? 'Active' : 'Inactive',
          color: active ? const Color(0xFF15803D) : const Color(0xFF64748B),
          icon: active
              ? Icons.check_circle_outline
              : Icons.pause_circle_outline,
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (role != 'student')
          OutlinedButton.icon(
            onPressed: !active
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffAssignmentPage(
                        uid: doc.id,
                        role: role,
                        name: name,
                      ),
                    ),
                  ),
            icon: Icon(
              role == 'teacher'
                  ? Icons.add_home_work_outlined
                  : Icons.assignment_ind_outlined,
              size: 17,
            ),
            label: Text(role == 'teacher' ? 'Sections' : 'Classes'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: _blue,
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        TextButton(
          onPressed: _busy.contains(doc.id) ? null : () => _toggle(doc),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: active
                ? const Color(0xFFB42318)
                : const Color(0xFF15803D),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: _busy.contains(doc.id)
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(active ? 'Deactivate' : 'Activate'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 12),
                labels,
                const SizedBox(height: 10),
                actions,
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                labels,
                const SizedBox(width: 12),
                actions,
              ],
            ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: db.collection('users').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Unable to load users. Check your connection.'),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final allUsers = snapshot.data!.docs.where((doc) {
        final role = doc.data()['role'];
        return ['teacher', 'trainer', 'student'].contains(role);
      }).toList();
      final activeCount = allUsers
          .where((doc) => doc.data()['isActive'] != false)
          .length;
      final inactiveCount = allUsers.length - activeCount;
      final docs =
          allUsers.where((doc) {
            final data = doc.data();
            final role = data['role'];
            final active = data['isActive'] != false;
            return (_role == 'all' || role == _role) &&
                (_status == 'all' || (_status == 'active') == active) &&
                '${data['name'] ?? data['displayName'] ?? ''} ${data['email'] ?? ''}'
                    .toLowerCase()
                    .contains(_search);
          }).toList()..sort(
            (a, b) => _name(
              a.data(),
            ).toLowerCase().compareTo(_name(b.data()).toLowerCase()),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, Color(0xFF155B78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'People & access',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manage school accounts, sections, and class assignments.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                );
                final buttons = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateStaffPage(),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add user'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _navy,
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateClassPage(),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add section'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ],
                );
                return compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading,
                          const SizedBox(height: 18),
                          buttons,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 20),
                          buttons,
                        ],
                      );
              },
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final cards = [
                _summaryCard(
                  label: 'Total users',
                  value: '${allUsers.length}',
                  icon: Icons.people_alt_outlined,
                  color: _blue,
                ),
                _summaryCard(
                  label: 'Active',
                  value: '$activeCount',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF15803D),
                ),
                _summaryCard(
                  label: 'Inactive',
                  value: '$inactiveCount',
                  icon: Icons.pause_circle_outline,
                  color: const Color(0xFF64748B),
                ),
              ];
              return compact
                  ? Column(
                      children: [
                        Row(
                          children: [
                            cards[0],
                            const SizedBox(width: 10),
                            cards[1],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(children: [cards[2]]),
                      ],
                    )
                  : Row(
                      children: [
                        cards[0],
                        const SizedBox(width: 12),
                        cards[1],
                        const SizedBox(width: 12),
                        cards[2],
                      ],
                    );
            },
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final search = TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search, color: _blue),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                );
                final roleFilter = DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'trainer', child: Text('Trainer')),
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                );
                final statusFilter = DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                );
                return compact
                    ? Column(
                        children: [
                          search,
                          const SizedBox(height: 10),
                          roleFilter,
                          const SizedBox(height: 10),
                          statusFilter,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 12),
                          SizedBox(width: 160, child: roleFilter),
                          const SizedBox(width: 12),
                          SizedBox(width: 160, child: statusFilter),
                        ],
                      );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'User directory',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${docs.length} ${docs.length == 1 ? 'user' : 'users'}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (docs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_search_outlined,
                    size: 36,
                    color: _muted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    allUsers.isEmpty
                        ? 'No users to show yet'
                        : 'No users match these filters',
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allUsers.isEmpty
                        ? 'Add a teacher or trainer to get started.'
                        : 'Try a different search or update your filters.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                return Column(
                  children: [
                    for (final doc in docs) ...[
                      _userCard(context, doc, compact),
                      if (doc != docs.last) const SizedBox(height: 9),
                    ],
                  ],
                );
              },
            ),
        ],
      );
    },
  );
}
