import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lrn_identity.dart';
export '../models/lrn_identity.dart';

class RegistrationInvitationService {
  RegistrationInvitationService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  Future<LrnIdentity> validateLrn(String lrn) async {
    if (!RegExp(r'^[0-9]{12}$').hasMatch(lrn)) {
      throw const FormatException('Enter a valid 12-digit LRN.');
    }
    final record = await _db
        .collection('lrn_master_list')
        .doc(lrn)
        .get(const GetOptions(source: Source.server));
    return LrnIdentity.fromMaster(lrn, record.data());
  }

  Future<void> claim({
    required String uid,
    required String lrn,
    required Map<String, dynamic> profile,
  }) async {
    if (!RegExp(r'^[0-9]{12}$').hasMatch(lrn) || uid.isEmpty) {
      throw const FormatException('Invalid registration identity.');
    }
    final master = _db.collection('lrn_master_list').doc(lrn);
    final user = _db.collection('users').doc(uid);
    final student = _db.collection('students').doc(uid);
    await _db.runTransaction((tx) async {
      final record = await tx.get(master);
      final existingUser = await tx.get(user);
      final existingStudent = await tx.get(student);
      final identity = LrnIdentity.fromMaster(lrn, record.data());
      if (existingUser.exists || existingStudent.exists) {
        throw const FormatException(
          'This account already has a profile. Sign in instead.',
        );
      }
      if (!identity.matchesProfile(profile)) {
        throw const FormatException(
          'The name does not match the current school record. Verify your LRN again or contact the school.',
        );
      }
      final canonical = {
        ...profile,
        ...identity.profileFields,
        'uid': uid,
        'role': 'student',
      };
      tx.set(user, canonical);
      tx.set(student, canonical);
      tx.update(master, {
        'isRegistered': true,
        'registeredAt': FieldValue.serverTimestamp(),
        'registeredUid': uid,
      });
    });
  }
}
