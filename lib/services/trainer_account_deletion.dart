import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Deletes only the current trainer's sign-in and top-level profile.
/// Shared academic records are retained.
class TrainerAccountDeletion {
  static Future<void> delete(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Sign in again before deleting your account.');
    }
    final profile = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snapshot = await profile.get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data?['role'] != 'trainer') {
      throw StateError('Only your own trainer account can be deleted here.');
    }
    await run(
      reauthenticate: () async {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      },
      removeProfile: profile.delete,
      removeAccount: user.delete,
      restoreProfile: () => profile.set(data!),
    );
  }

  static Future<void> run({
    required Future<void> Function() reauthenticate,
    required Future<void> Function() removeProfile,
    required Future<void> Function() removeAccount,
    required Future<void> Function() restoreProfile,
  }) async {
    await reauthenticate();
    await removeProfile();
    try {
      await removeAccount();
    } catch (_) {
      try {
        await restoreProfile();
      } catch (_) {
        throw StateError(
          'Account deletion did not finish and your profile could not be restored. Contact your administrator before retrying.',
        );
      }
      rethrow;
    }
  }
}
