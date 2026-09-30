import 'package:cloud_firestore/cloud_firestore.dart';

class LrnManagementService {
  LrnManagementService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<String> createFolder(String name, {required String kind}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const FormatException('Enter a folder name of 1-80 characters.');
    }
    if (kind != 'batch' && kind != 'class') {
      throw const FormatException('Choose Batch or Class.');
    }
    final folder = await _db.collection('lrn_folders').add({
      'name': trimmed,
      'kind': kind,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return folder.id;
  }

  Future<void> move(String lrn, String folderId) =>
      _db.collection('lrn_master_list').doc(lrn).update({'folderId': folderId});

  Future<void> delete(String lrn) async {
    final ref = _db.collection('lrn_master_list').doc(lrn);
    await _db.runTransaction((tx) async {
      final record = await tx.get(ref);
      if (!record.exists) return;
      // Preserve claimed identities so re-import cannot enable a second account.
      // This transactional read also protects concurrent registration.
      if (record.data()?['isRegistered'] == true) {
        tx.update(ref, {'archived': true});
      } else {
        tx.delete(ref);
      }
    });
  }

  Future<int> deleteFolder(String folderId) async {
    if (folderId.isEmpty) {
      throw const FormatException('The Unfiled folder cannot be deleted.');
    }
    final records = await _db
        .collection('lrn_master_list')
        .where('folderId', isEqualTo: folderId)
        .get();
    for (final record in records.docs) {
      await delete(record.id);
    }
    await _db.collection('lrn_folders').doc(folderId).delete();
    return records.docs.length;
  }
}
