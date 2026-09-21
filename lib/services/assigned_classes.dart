import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Watches only the classes in the user's memberships, in bounded ID queries.
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAssignedClasses(
  FirebaseFirestore db,
  String uid,
) {
  late StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  output;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? memberships;
  final batches = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  var generation = 0;
  String? previousIds;
  var stopped = false;
  output = StreamController(
    onListen: () {
      memberships = db
          .collection('users')
          .doc(uid)
          .collection('classes')
          .snapshots()
          .listen(
            (snapshot) async {
              final ids =
                  snapshot.docs
                      .map((doc) {
                        final id = doc.data()['classId']?.toString().trim();
                        return id == null || id.isEmpty ? doc.id : id;
                      })
                      .toSet()
                      .toList()
                    ..sort();
              final signature = ids.join('/');
              if (signature == previousIds) return;
              previousIds = signature;
              final version = ++generation;
              final old = batches.toList();
              batches.clear();
              await Future.wait(
                old.map((subscription) => subscription.cancel()),
              );
              if (stopped || version != generation) return;
              if (ids.isEmpty) {
                output.add([]);
                return;
              }
              final results =
                  <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
              final count = (ids.length / 10).ceil();
              for (var offset = 0; offset < ids.length; offset += 10) {
                final batch = offset ~/ 10;
                final end = offset + 10 < ids.length ? offset + 10 : ids.length;
                batches.add(
                  db
                      .collection('classes')
                      .where(
                        FieldPath.documentId,
                        whereIn: ids.sublist(offset, end),
                      )
                      .snapshots()
                      .listen(
                        (classes) {
                          if (stopped || version != generation) return;
                          results[batch] = classes.docs;
                          if (results.length == count) {
                            output.add([
                              for (var i = 0; i < count; i++) ...results[i]!,
                            ]);
                          }
                        },
                        onError: (Object error, StackTrace trace) {
                          if (!stopped && version == generation)
                            output.addError(error, trace);
                        },
                      ),
                );
              }
            },
            onError: (Object error, StackTrace trace) {
              if (!stopped) output.addError(error, trace);
            },
          );
    },
    onCancel: () async {
      stopped = true;
      generation++;
      await memberships?.cancel();
      await Future.wait(batches.map((subscription) => subscription.cancel()));
    },
  );
  return output.stream;
}
