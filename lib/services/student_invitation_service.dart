import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static Future<StudentInvitationResult> invite({
    required String classId,
    required String email,
    String firstName = '',
    String lastName = '',
    bool skipIfAlreadyInvited = false,
  }) async {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      throw const StudentInvitationException(
        'Your session has expired. Sign in again.',
      );
    }

    final address = email.trim().toLowerCase();
    final first = firstName.trim();
    final last = lastName.trim();
    if (!_emailPattern.hasMatch(address) || address.length > 254) {
      throw const StudentInvitationException(
        'Check this student email address.',
        stopBatch: false,
      );
    }
    if (first.length > 80 || last.length > 80) {
      throw const StudentInvitationException(
        'Student names can contain at most 80 characters.',
        stopBatch: false,
      );
    }
    if (classId.trim().isEmpty ||
        classId.length > 128 ||
        classId.contains('/')) {
      throw const StudentInvitationException(
        'This class is unavailable. Reopen Student Management and retry.',
      );
    }

    final db = FirebaseFirestore.instance;
    final classroom = db.collection('classes').doc(classId);
    final classSnapshot = await classroom.get();
    if (!classSnapshot.exists) {
      throw const StudentInvitationException(
        'This class is unavailable. Reopen Student Management and retry.',
      );
    }
    if (classSnapshot.data()?['teacherId'] != teacher.uid) {
      throw const StudentInvitationException(
        'Only the assigned teacher can invite students to this class.',
      );
    }

    final matches = await db
        .collection('users')
        .where('email', isEqualTo: address)
        .limit(2)
        .get();
    if (matches.docs.length > 1) {
      throw const StudentInvitationException(
        'Duplicate student profiles use this email. Ask the system administrator to correct them.',
      );
    }

    _TemporaryStudentAccount? createdAccount;
    late final String uid;
    Map<String, dynamic>? stored;
    if (matches.docs.isNotEmpty) {
      final profile = matches.docs.single;
      stored = profile.data();
      if (stored['role'] != 'student') {
        throw const StudentInvitationException(
          'This email belongs to a non-student account.',
          stopBatch: false,
        );
      }
      uid = profile.id;
    } else {
      try {
        createdAccount = await _TemporaryStudentAccount.create(address);
        uid = createdAccount.uid;
      } on FirebaseAuthException catch (error) {
        if (error.code == 'email-already-in-use') {
          throw const StudentInvitationException(
            'This email already has an account but no student profile. Ask the system administrator to repair it.',
            stopBatch: false,
          );
        }
        throw _authFailure(error);
      }
    }

    final member = classroom.collection('students').doc(uid);
    final membership = await member.get();
    final memberData = membership.data() ?? const <String, dynamic>{};
    final enrolledIds = List<String>.from(
      classSnapshot.data()?['enrolledStudentIds'] ?? const <String>[],
    );
    final enrolled = membership.exists || enrolledIds.contains(uid);
    if (skipIfAlreadyInvited &&
        enrolled &&
        (memberData['notificationSent'] == true ||
            memberData['invitationStatus'] != 'pending')) {
      await createdAccount?.close();
      return const StudentInvitationResult(skipped: true);
    }

    final storedFirst = stored?['firstName']?.toString().trim() ?? '';
    final storedLast = stored?['lastName']?.toString().trim() ?? '';
    final resolvedFirst = stored == null ? first : storedFirst;
    final resolvedLast = stored == null ? last : storedLast;
    final storedName = stored?['name']?.toString().trim() ?? '';
    final storedDisplayName = stored?['displayName']?.toString().trim() ?? '';
    final enteredName = [
      resolvedFirst,
      resolvedLast,
    ].where((part) => part.isNotEmpty).join(' ');
    final displayName = storedName.isNotEmpty
        ? storedName
        : storedDisplayName.isNotEmpty
        ? storedDisplayName
        : enteredName.isNotEmpty
        ? enteredName
        : 'Student';
    final now = FieldValue.serverTimestamp();
    final profileData = <String, dynamic>{
      'uid': uid,
      'email': address,
      'role': 'student',
      'firstName': resolvedFirst,
      'lastName': resolvedLast,
      'name': displayName,
      'displayName': displayName,
      'invitationStatus': 'pending',
      'invitedAt': now,
      'invitedBy': teacher.uid,
      'invitedClassId': classId,
      'createdAt': now,
      'updatedAt': now,
    };

    try {
      final batch = db.batch();
      if (stored == null) {
        batch.set(db.collection('users').doc(uid), profileData);
        batch.set(db.collection('students').doc(uid), profileData);
      }
      batch.set(member, {
        ...profileData,
        'classId': classId,
        'notificationSent': false,
      }, SetOptions(merge: true));
      batch.update(classroom, {
        'enrolledStudentIds': FieldValue.arrayUnion([uid]),
      });
      await batch.commit();
    } catch (_) {
      await createdAccount?.deleteAndClose();
      rethrow;
    }
    await createdAccount?.close();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
      await member.set({
        'invitationStatus': 'sent',
        'notificationSent': true,
        'notifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return const StudentInvitationResult();
    } on FirebaseAuthException catch (error) {
      throw _authFailure(error);
    } on FirebaseException catch (error) {
      throw StudentInvitationException(
        error.message ??
            'The account was enrolled, but Firebase did not confirm the email. Retry this address.',
      );
    } on TimeoutException {
      throw const StudentInvitationException(
        'The account was enrolled, but email delivery timed out. Check the inbox before retrying.',
      );
    }
  }

  static StudentInvitationException _authFailure(FirebaseAuthException error) {
    if (error.code == 'invalid-email') {
      return const StudentInvitationException(
        'Check this student email address.',
        stopBatch: false,
      );
    }
    if (error.code == 'too-many-requests' || error.code == 'quota-exceeded') {
      return const StudentInvitationException(
        'Firebase is temporarily limiting invitation emails. Wait before retrying the remaining students.',
      );
    }
    if (error.code == 'network-request-failed') {
      return const StudentInvitationException(
        'Connection interrupted. The account may be enrolled, but email delivery was not confirmed. Check the inbox before retrying.',
      );
    }
    return StudentInvitationException(
      error.message ??
          'Firebase did not confirm the invitation. Check the student inbox before retrying.',
    );
  }

  static String _temporaryPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final random = Random.secure();
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

class _TemporaryStudentAccount {
  _TemporaryStudentAccount(this.app, this.auth, this.user);

  final FirebaseApp app;
  final FirebaseAuth auth;
  final User user;
  String get uid => user.uid;

  static Future<_TemporaryStudentAccount> create(String email) async {
    final app = await Firebase.initializeApp(
      name: 'student-invite-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: StudentInvitationService._temporaryPassword(),
      );
      final user = credential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-not-created');
      return _TemporaryStudentAccount(app, auth, user);
    } catch (_) {
      await auth.signOut();
      await app.delete();
      rethrow;
    }
  }

  Future<void> deleteAndClose() async {
    try {
      await user.delete();
    } finally {
      await close();
    }
  }

  Future<void> close() async {
    try {
      await auth.signOut();
    } finally {
      await app.delete();
    }
  }
}
