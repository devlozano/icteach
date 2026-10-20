import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationEnrollmentException implements Exception {
  const InvitationEnrollmentException(this.message);
  final String message;

  @override
  String toString() => message;
}

class InvitationEnrollmentService {
  static Map<String, dynamic> membershipData(
    String classId,
    Map<String, dynamic> classroom,
  ) {
    return {
      'classId': classId,
      'className': classroom['name']?.toString() ?? 'Unnamed Class',
      'description': classroom['description']?.toString() ?? '',
      'sectionCode': classroom['sectionCode']?.toString() ?? '',
      'classCode': classroom['classCode']?.toString() ?? '',
      'teacherId': classroom['teacherId']?.toString() ?? '',
      'teacherName': classroom['teacherName']?.toString() ?? 'Unknown Teacher',
      'teacherEmail': classroom['teacherEmail']?.toString() ?? '',
      'schoolYear': classroom['schoolYear']?.toString() ?? '',
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    };
  }

  static Future<bool> reconcile({
    required FirebaseFirestore firestore,
    required String uid,
    required String authEmail,
  }) async {
    final user = firestore.collection('users').doc(uid);
    final profile = await user.get();
    final data = profile.data();
    if (data == null || data['role'] != 'student') return false;

    final classId = data['invitedClassId']?.toString().trim() ?? '';
    if (classId.isEmpty) return false;
    final profileEmail = data['email']?.toString().trim().toLowerCase() ?? '';
    if (profileEmail.isEmpty ||
        profileEmail != authEmail.trim().toLowerCase()) {
      throw const InvitationEnrollmentException(
        'This invitation does not match the signed-in Gmail account.',
      );
    }

    final classroom = firestore.collection('classes').doc(classId);
    final member = classroom.collection('students').doc(uid);
    final snapshots = await Future.wait([classroom.get(), member.get()]);
    final classSnapshot = snapshots[0];
    final memberSnapshot = snapshots[1];
    final classData = classSnapshot.data();
    if (classData == null || classData['status'] == 'archived') {
      throw const InvitationEnrollmentException(
        'The class in this invitation is no longer available.',
      );
    }
    final enrolledIds = List<String>.from(
      classData['enrolledStudentIds'] ?? const <String>[],
    );
    if (!memberSnapshot.exists || !enrolledIds.contains(uid)) {
      throw const InvitationEnrollmentException(
        'Your invitation is incomplete. Ask your teacher to resend it.',
      );
    }

    final student = firestore.collection('students').doc(uid);
    final studentSnapshot = await student.get();
    final className = classData['name']?.toString() ?? 'Unnamed Class';
    final teacherName =
        classData['teacherName']?.toString() ?? 'Unknown Teacher';
    final updates = <String, dynamic>{
      'currentClassId': classId,
      'currentClassName': className,
      'currentTeacherName': teacherName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = firestore.batch();
    batch.set(
      user.collection('classes').doc(classId),
      membershipData(classId, classData),
      SetOptions(merge: true),
    );
    batch.update(user, updates);
    if (studentSnapshot.exists) batch.update(student, updates);
    await batch.commit();
    return true;
  }
}
