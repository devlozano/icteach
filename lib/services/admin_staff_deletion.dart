import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class AdminStaffDeletion {
  /// Revokes ICTeach access when a project cannot run Cloud Functions.
  static Future<void> revokeAccess(
    String uid,
    String role, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? callerUid,
  }) async {
    if (uid.trim().isEmpty || !['teacher', 'trainer'].contains(role)) {
      throw StateError('Select a teacher or trainer account to remove.');
    }
    final currentUid =
        callerUid ?? (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (currentUid == null) {
      throw StateError('Your session has expired. Sign in again.');
    }
    if (currentUid == uid) {
      throw StateError('You cannot remove the account you are signed in with.');
    }
    final profile = (firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid);
    final snapshot = await profile.get();
    final data = snapshot.data();
    if (!snapshot.exists || data?['role'] != role) {
      throw StateError(
        'The staff profile is missing or its role changed. Refresh the staff list.',
      );
    }
    await profile.update({
      'isActive': false,
      'accessRevokedAt': FieldValue.serverTimestamp(),
      'accessRevokedBy': currentUid,
    });
  }

  static Future<void> delete(
    String uid,
    String role, {
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String? projectId,
  }) async {
    if (uid.trim().isEmpty || !['teacher', 'trainer'].contains(role)) {
      throw StateError('Select a teacher or trainer account to delete.');
    }
    final transport = client ?? http.Client();
    try {
      final String? token;
      if (tokenProvider != null) {
        token = await tokenProvider();
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null)
          throw StateError('Your session has expired. Sign in again.');
        token = await user.getIdToken(true);
      }
      if (token == null || token.isEmpty) {
        throw StateError('Your session has expired. Sign in again.');
      }
      final project = projectId ?? Firebase.app().options.projectId;
      final response = await transport
          .post(
            Uri.https(
              'us-central1-$project.cloudfunctions.net',
              '/deleteStaffAccount',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'uid': uid, 'role': role}),
          )
          .timeout(const Duration(seconds: 135));
      Map<String, dynamic> body = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        /* Hosting errors can be HTML, not JSON. */
      }
      if (response.statusCode == 200 && body['deleted'] == true) return;
      final code = body['error'];
      if (response.statusCode == 401)
        throw StateError(
          'Your session has expired. Sign in again, then retry.',
        );
      if (code == 'self-deletion-forbidden')
        throw StateError(
          'You cannot delete the account you are signed in with.',
        );
      if (code == 'protected-admin')
        throw StateError(
          'Administrator accounts cannot be deleted from the staff list.',
        );
      if (response.statusCode == 403)
        throw StateError(
          'Administrator authorization is required. Ask the system owner to verify your Admin claim and the deletion service configuration.',
        );
      if (response.statusCode == 404)
        throw StateError(
          'The account deletion service is unavailable. The system owner must deploy deleteStaffAccount for this project.',
        );
      if (response.statusCode == 409)
        throw StateError(
          'The staff profile is missing or its role changed. Refresh the staff list before retrying.',
        );
      if (response.statusCode == 400)
        throw StateError(
          'The account selection is invalid. Refresh the staff list.',
        );
      throw StateError(
        'Deletion could not finish. Refresh the staff list and retry if the account remains; shared classes are preserved.',
      );
    } on TimeoutException {
      throw StateError(
        'The deletion request timed out and may still be processing. Refresh the staff list before retrying.',
      );
    } on http.ClientException {
      throw StateError(
        'Cannot reach the account deletion service. Check your connection. If you are online, the system owner must deploy or repair deleteStaffAccount.',
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'network-request-failed') {
        throw StateError(
          'Could not verify your session. Check your connection and retry.',
        );
      }
      throw StateError(
        'Your session could not be verified. Sign in again, then retry.',
      );
    } finally {
      if (client == null) transport.close();
    }
  }
}
