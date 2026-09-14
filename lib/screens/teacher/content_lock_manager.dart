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
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        categoryLocked
            ? 'Category is locked; unlock the category first'
            : locked
            ? 'Locked for students'
            : 'Available to students',
      ),
      secondary: Icon(locked || categoryLocked ? Icons.lock : Icons.lock_open),
      value: !locked,
      onChanged:
          categoryLocked ||
              _saving.contains(
                ContentAccessService.lockId(widget.classId, type, id),
              )
          ? null
          : (value) => _toggle(type, id, !value, records),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage content access')),
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
                const Text(
                  'Turn an activity off to lock it. Students already viewing it will also see the lock. Simulation prerequisites still apply after unlocking.',
                ),
                for (final type in ['module', 'quiz', 'simulation']) ...[
                  const Divider(),
                  _tile(type, '*', 'All ${type}s', records),
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
                          return const ListTile(
                            title: Text('Content could not be loaded.'),
                          );
                        }
                        if (!content.hasData) {
                          return const LinearProgressIndicator();
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
                ],
              ],
            );
          },
        );
      },
    ),
  );
}
