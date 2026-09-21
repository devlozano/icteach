import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolYearService {
  /// Class documents are authoritative; membership copies may predate rollover.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  activeMemberships(String uid) async {
    final db = FirebaseFirestore.instance;
    final memberships = await db
        .collection('users')
        .doc(uid)
        .collection('classes')
        .get();
    final active = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var offset = 0; offset < memberships.docs.length; offset += 10) {
      final batch = memberships.docs.skip(offset).take(10).toList();
      final classrooms = await Future.wait(
        batch.map(
          (membership) => db
              .collection('classes')
              .doc(membership.data()['classId']?.toString() ?? membership.id)
              .get(),
        ),
      );
      for (var i = 0; i < batch.length; i++) {
        if (classrooms[i].exists &&
            classrooms[i].data()?['status'] != 'archived')
          active.add(batch[i]);
      }
    }
    active.sort(
      (a, b) =>
          ((b.data()['joinedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
              .compareTo(
                (a.data()['joinedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0,
              ),
    );
    return active;
  }
}
