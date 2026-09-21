import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class AdminStaffDeletion {
  static Future<void> delete(String uid, String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in again.');
    final token = await user.getIdToken(true);
    final project = Firebase.app().options.projectId;
    final response = await http
        .post(
          Uri.https(
            'us-central1-' + project + '.cloudfunctions.net',
            '/deleteStaffAccount',
          ),
          headers: {
            'Authorization': 'Bearer ' + (token ?? ''),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'uid': uid, 'role': role}),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      if (response.statusCode == 403)
        throw StateError(
          'Administrator authorization is required. Ask the system owner to enable your Admin claim.',
        );
      if (response.statusCode == 404)
        throw StateError(
          'The account deletion service is not deployed yet. Contact the system owner.',
        );
      if (response.statusCode == 409)
        throw StateError(
          'The account role changed. Refresh the account list before retrying.',
        );
      throw StateError(
        'Could not finish deletion. Please retry; shared class records are preserved.',
      );
    }
  }
}
