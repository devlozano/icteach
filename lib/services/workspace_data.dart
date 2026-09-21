import 'combine_latest.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'live_stream_cache.dart';
import 'assigned_classes.dart';

class WorkspaceData {
  static final _cache = LiveStreamCache();
  static String? _owner;
  static void clear() {
    _owner = null;
    _cache.clear();
  }

  static Stream<T> watch<T>(String key, Stream<T> Function() create) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_owner != uid) {
      clear();
      _owner = uid;
    }
    return _cache.watch(key, create);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      watch(
        'profile/$uid',
        () =>
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      );
  static Stream<QuerySnapshot<Map<String, dynamic>>> teacherClasses(
    String uid,
  ) => watch(
    'teacherClasses/$uid',
    () => FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: uid)
        .snapshots(),
  );
  static Stream<QuerySnapshot<Map<String, dynamic>>> memberships(String uid) =>
      watch(
        'memberships/$uid',
        () => FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('classes')
            .snapshots(),
      );
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  assignedClasses(String uid) => watch(
    'assignedClasses/$uid',
    () => watchAssignedClasses(FirebaseFirestore.instance, uid),
  );
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  teacherClassDocs(String uid) => watch(
    'teacherClassDocs/$uid',
    () => teacherClasses(uid).map((snapshot) => snapshot.docs),
  );
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  activeMemberships(String uid) => watch(
    'activeMemberships/$uid',
    () =>
        combineLatest<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
          memberships(uid).map((snapshot) => snapshot.docs),
          assignedClasses(uid),
        ]).map((data) {
          final activeIds = {
            for (final c in data[1])
              if (c.data()['status'] != 'archived') c.id,
          };
          final result = data[0].where((doc) {
            final id = doc.data()['classId']?.toString().trim();
            return activeIds.contains(id == null || id.isEmpty ? doc.id : id);
          }).toList();
          result.sort(
            (a, b) =>
                ((b.data()['joinedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                        0)
                    .compareTo(
                      (a.data()['joinedAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0,
                    ),
          );
          return result;
        }),
  );
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> students(
    Set<String>? ids,
  ) {
    if (ids == null)
      return watch(
        'allStudents',
        () => FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .snapshots()
            .map((s) => s.docs),
      );
    final sorted = ids.toList()..sort();
    return watch('students/' + sorted.join(','), () {
      final queries =
          <Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[];
      for (var i = 0; i < sorted.length; i += 10) {
        queries.add(
          FirebaseFirestore.instance
              .collection('users')
              .where(
                FieldPath.documentId,
                whereIn: sorted.sublist(
                  i,
                  i + 10 < sorted.length ? i + 10 : sorted.length,
                ),
              )
              .snapshots()
              .map(
                (s) =>
                    s.docs.where((d) => d.data()['role'] == 'student').toList(),
              ),
        );
      }
      return combineLatest(
        queries,
      ).map((groups) => groups.expand((group) => group).toList());
    });
  }
}
