import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class StudentInvitationService {
  static Future<void> invite({
    required String classId,
    required String email,
    String firstName = '',
    String lastName = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      throw StateError('Your session has expired. Sign in again.');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty)
      throw StateError('Your session has expired. Sign in again.');
    final project = Firebase.app().options.projectId;
    final response = await http
        .post(
          Uri.https(
            'us-central1-$project.cloudfunctions.net',
            '/inviteStudentAccount',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'classId': classId,
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
          }),
        )
        .timeout(const Duration(seconds: 135));
    if (response.statusCode == 200) return;
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // A missing Function may return an HTML 404 page rather than JSON.
    }
    final error = body?['error'];
    if (error == 'invalid-email')
      throw StateError('Enter a valid student email address.');
    if (error == 'email-in-use')
      throw StateError('That email belongs to a non-student account.');
    if (error == 'teacher-class-required')
      throw StateError(
        'Only the assigned teacher can invite students to this class.',
      );
    if (error == 'class-not-found')
      throw StateError(
        'This class is no longer available. Reopen Student Management and retry.',
      );
    if (response.statusCode == 404) {
      throw StateError(
        'Student invitations are not deployed yet. Ask the system owner to deploy inviteStudentAccount and configure EmailJS.',
      );
    }
    throw StateError(
      'The invitation could not be sent. Check the EmailJS configuration and retry.',
    );
  }
}
