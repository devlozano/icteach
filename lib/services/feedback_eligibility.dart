import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackEligibility {
  static bool isQualified(Map<String, dynamic>? profile) =>
      profile?['role'] == 'student' && profile?['nc2Passed'] == true;

  static Future<void> requireQualified({
    FirebaseFirestore? firestore,
    String? userId,
  }) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    final profile = await (firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (!isQualified(profile.data())) {
      throw StateError(
        'System feedback is available after your NC II qualification is recorded.',
      );
    }
  }
}
