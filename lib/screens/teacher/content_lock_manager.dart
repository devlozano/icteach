import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/simulation_data.dart';
import '../../services/content_access_service.dart';

class ContentLockManager extends StatefulWidget {
  final String classId;
  const ContentLockManager({super.key, required this.classId});
  @override
  State<ContentLockManager> createState() => _ContentLockManagerState();
}

class _ContentLockManagerState extends State<ContentLockManager> {
  late final _staff = ContentAccessService.isClassStaff(widget.classId);
  late final _locks = ContentAccessService.locks(widget.classId);
  final Set<String> _saving = {};
  Future<void> _toggle(
    String type,
    String id,
    bool locked,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
  ) async {
    final key = ContentAccessService.lockId(widget.classId, type, id);
    if (_saving.contains(key)) return;
    setState(() => _saving.add(key));
    try {
      if (!await ContentAccessService.isClassStaff(widget.classId)) {
        throw StateError('Staff access required.');
      }
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      // Update legacy auto-ID records too, so a previous lock cannot remain hidden.
      for (final doc in records.where(
        (d) =>
            d.data()['contentId'] == id &&
            (d.data()['contentType'] == type ||
                (type == 'quiz' && d.data()['contentType'] == 'practice')),
      )) {
        batch.update(doc.reference, {
          'isLocked': locked,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.set(db.collection('content_locks').doc(key), {
        'classId': widget.classId,
        'contentType': type,
        'contentId': id,
        'isLocked': locked,
        'updatedBy': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save access settings. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Widget _tile(
    String type,
    String id,
    String title,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
  ) {
    final locked = records.any(
      (d) =>
          d.data()['contentId'] == id &&
          ContentAccessService.isLocked([d.data()], type, id),
    );
    final categoryLocked =
        id != '*' &&
        ContentAccessService.isLocked(records.map((d) => d.data()), type, '*');
    final saving = _saving.contains(
      ContentAccessService.lockId(widget.classId, type, id),
    );
    final unavailable = locked || categoryLocked;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: categoryLocked ? const Color(0xFFF8FAFC) : Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(right: 7),
                  child: SizedBox.square(
                    dimension: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Flexible(
                child: Text(
                  saving
                      ? 'Saving access…'
                      : categoryLocked
                      ? 'Unlock this category to change the item'
                      : unavailable
                      ? 'Locked for students'
                      : 'Available to students',
                  style: TextStyle(
                    color: unavailable
                        ? const Color(0xFFB45309)
                        : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: unavailable
                ? const Color(0xFFFFF7ED)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            unavailable ? Icons.lock_outline : Icons.lock_open_outlined,
            color: unavailable
                ? const Color(0xFFEA580C)
                : const Color(0xFF16A34A),
          ),
        ),
        value: !locked,
        onChanged: categoryLocked || saving
            ? null
            : (value) => _toggle(type, id, !value, records),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    appBar: AppBar(
      backgroundColor: const Color(0xFF172554),
      foregroundColor: Colors.white,
      title: const Text('Manage content access'),
    ),
    body: FutureBuilder<bool>(
      future: _staff,
      builder: (context, staff) {
        if (staff.hasError) {
          return const Center(
            child: Text(
              'Unable to verify staff access. Reopen this page to retry.',
            ),
          );
        }
        if (!staff.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (staff.data != true) {
          return const Center(
            child: Text(
              'Only this class teacher or trainer can manage access.',
            ),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _locks,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load access settings. Reopen this page to retry.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = snapshot.data!.docs;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _AccessHero(),
                const SizedBox(height: 18),
                for (final type in ['module', 'quiz', 'simulation']) ...[
                  _AccessHeader(type: type),
                  _tile(type, '*', switch (type) {
                    'module' => 'All lessons & modules',
                    'quiz' => 'All quizzes & assessments',
                    _ => 'All practical simulations',
                  }, records),
                  if (type == 'simulation')
                    for (final sim in SimulationData.getAllSimulations())
                      _tile(
                        type,
                        sim.id,
                        '${sim.competency}: ${sim.title}',
                        records,
                      )
                  else
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('classes')
                          .doc(widget.classId)
                          .collection('${type}s')
                          .snapshots(),
                      builder: (context, content) {
                        if (content.hasError) {
                          return const _AccessNotice(
                            icon: Icons.cloud_off_outlined,
                            text: 'Content could not be loaded.',
                          );
                        }
                        if (!content.hasData) {
                          return const LinearProgressIndicator();
                        }
                        if (content.data!.docs.isEmpty) {
                          return const _AccessNotice(
                            icon: Icons.inbox_outlined,
                            text: 'No content has been added yet.',
                          );
                        }
                        return Column(
                          children: content.data!.docs
                              .map(
                                (d) => _tile(
                                  type,
                                  d.id,
                                  d.data()['title']?.toString() ?? 'Untitled',
                                  records,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        );
      },
    ),
  );
}

class _AccessHero extends StatelessWidget {
  const _AccessHero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F766E), Color(0xFF0369A1)],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x241D4ED8),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.admin_panel_settings_outlined,
          color: Colors.white,
          size: 30,
        ),
        const SizedBox(height: 12),
        Text(
          'Choose what students can access',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Switch a category or individual item on to make it available. Changes apply to enrolled students immediately.',
          style: TextStyle(color: Color(0xFFD6F4F1), height: 1.4),
        ),
        const SizedBox(height: 15),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AccessLegend(color: Color(0xFF86EFAC), label: 'On · Available'),
            _AccessLegend(color: Color(0xFFFDBA74), label: 'Off · Locked'),
          ],
        ),
      ],
    ),
  );
}

class _AccessLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _AccessLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _AccessHeader extends StatelessWidget {
  final String type;
  const _AccessHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    final (title, description, icon) = switch (type) {
      'module' => (
        'Lessons & modules',
        'Control which learning materials students can open.',
        Icons.menu_book_outlined,
      ),
      'quiz' => (
        'Quizzes & assessments',
        'Open or close quizzes without removing their content.',
        Icons.quiz_outlined,
      ),
      _ => (
        'Practical simulations',
        'Learning prerequisites still apply after access is enabled.',
        Icons.precision_manufacturing_outlined,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFECFEFF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172554),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  const _AccessNotice({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF64748B))),
        ),
      ],
    ),
  );
}
