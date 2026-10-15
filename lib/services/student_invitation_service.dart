import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class StudentInvitationService {
  static Future<void> invite({required String email, String firstName = '', String lastName = ''}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Your session has expired. Sign in again.');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw StateError('Your session has expired. Sign in again.');
    final project = Firebase.app().options.projectId;
    final response = await http.post(Uri.https('us-central1-$project.cloudfunctions.net', '/inviteStudentAccount'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'firstName': firstName, 'lastName': lastName}));
    if (response.statusCode == 200) return;
    final error = (jsonDecode(response.body) as Map?)?['error'];
    if (error == 'invalid-email') throw StateError('Enter a valid student email address.');
    if (error == 'email-in-use') throw StateError('That email belongs to a non-student account.');
    if (response.statusCode == 403) throw StateError('Administrator authorization is required to invite students.');
    throw StateError('The invitation could not be sent. Check the EmailJS configuration and retry.');
  }
}
