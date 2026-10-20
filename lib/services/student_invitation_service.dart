import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class StudentInvitationException implements Exception {
  const StudentInvitationException(this.message, {this.stopBatch = true});
  final String message;
  final bool stopBatch;
  @override
  String toString() => message;
}

class StudentInvitationResult {
  const StudentInvitationResult({this.skipped = false});
  final bool skipped;
}

class StudentInvitationService {
  static Future<StudentInvitationResult> invite({
    required String classId,
    required String email,
    String firstName = '',
    String lastName = '',
    bool skipIfAlreadyInvited = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const StudentInvitationException(
        'Your session has expired. Sign in again.',
      );
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const StudentInvitationException(
        'Your session has expired. Sign in again.',
      );
    }
    final project = Firebase.app().options.projectId;
    http.Response response;
    try {
      response = await http
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
              'skipIfAlreadyInvited': skipIfAlreadyInvited,
            }),
          )
          .timeout(const Duration(seconds: 135));
    } on TimeoutException {
      throw const StudentInvitationException(
        'The server did not confirm delivery in time. Check the student inbox before retrying this address.',
      );
    } on http.ClientException {
      throw const StudentInvitationException(
        'Connection interrupted. Delivery was not confirmed. Check the student inbox before retrying.',
      );
    }
    return parseResponse(response.statusCode, response.body);
  }

  static StudentInvitationResult parseResponse(
    int status,
    String responseBody,
  ) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      /* An unavailable Function may return HTML. */
    }
    if (status == 200 && body?['skipped'] == true) {
      return const StudentInvitationResult(skipped: true);
    }
    if (status == 200 && body?['notificationSent'] == true) {
      return const StudentInvitationResult();
    }
    final error = body?['error'];
    if (error == 'invalid-email' || error == 'invalid-name') {
      throw const StudentInvitationException(
        'Check this student email address and names (80 characters maximum).',
        stopBatch: false,
      );
    }
    if (error == 'email-in-use') {
      throw const StudentInvitationException(
        'This email belongs to a non-student account.',
        stopBatch: false,
      );
    }
    if (error == 'teacher-class-required' || status == 403) {
      throw const StudentInvitationException(
        'Only the assigned teacher can invite students to this class.',
      );
    }
    if (error == 'class-not-found' || error == 'invalid-class') {
      throw const StudentInvitationException(
        'This class is unavailable. Reopen Student Management and retry.',
      );
    }
    if (status == 401) {
      throw const StudentInvitationException(
        'Your session has expired. Sign in again.',
      );
    }
    if (status == 404) {
      throw const StudentInvitationException(
        'Student invitations are not deployed yet. Ask the system owner to deploy inviteStudentAccount and configure EmailJS.',
      );
    }
    if (status == 429) {
      throw const StudentInvitationException(
        'The invitation service is temporarily limiting requests. Wait before retrying the remaining students.',
      );
    }
    throw const StudentInvitationException(
      'Delivery was not confirmed. Check the student inbox and invitation service configuration before retrying.',
    );
  }
}
