import 'package:cloud_firestore/cloud_firestore.dart';

import 'student_account_repair.dart';

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
    if (data == null) {
      return _claimMissingProfile(
        firestore: firestore,
        uid: uid,
        authEmail: authEmail,
      );
    }
    if (data['role'] != 'student') return false;

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
    final classSnapshot = await classroom.get();
    final classData = classSnapshot.data();
    if (classData == null || classData['status'] == 'archived') {
      throw const InvitationEnrollmentException(
        'The class in this invitation is no longer available.',
      );
    }
    final enrolledIds = List<String>.from(
      classData['enrolledStudentIds'] ?? const <String>[],
    );
    // A removed student cannot read the private roster anymore.
    if (!enrolledIds.contains(uid)) {
      final repairId = data['accountRepairId']?.toString() ?? '';
      if (repairId.isEmpty) return false;
      await _markRepairClaimed(
        firestore: firestore,
        repairId: repairId,
        uid: uid,
      );
      await _completeRecoveredEnrollment(
        firestore: firestore,
        uid: uid,
        profile: data,
        classroom: classroom,
        classId: classId,
        classData: classData,
      );
      return true;
    }
    final memberSnapshot = await member.get();
    if (!memberSnapshot.exists) {
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

  static Future<bool> _claimMissingProfile({
    required FirebaseFirestore firestore,
    required String uid,
    required String authEmail,
  }) async {
    final email = authEmail.trim().toLowerCase();
    if (email.isEmpty) return false;
    final repairId = studentAccountRepairId(email);
    final repair = firestore
        .collection('student_account_repairs')
        .doc(repairId);
    final repairSnapshot = await repair.get();
    final invitation = repairSnapshot.data();
    if (invitation == null || invitation['status'] != 'pending') return false;
    if (invitation['email']?.toString().trim().toLowerCase() != email) {
      throw const InvitationEnrollmentException(
        'This invitation does not match the signed-in Gmail account.',
      );
    }

    final classId = invitation['classId']?.toString().trim() ?? '';
    if (classId.isEmpty) {
      throw const InvitationEnrollmentException(
        'This invitation is incomplete. Ask your teacher to resend it.',
      );
    }
    final classroom = firestore.collection('classes').doc(classId);
    final classSnapshot = await classroom.get();
    final classData = classSnapshot.data();
    if (classData == null || classData['status'] == 'archived') {
      throw const InvitationEnrollmentException(
        'The class in this invitation is no longer available.',
      );
    }
    if (classData['teacherId'] != invitation['teacherId']) {
      throw const InvitationEnrollmentException(
        'This invitation no longer matches the assigned teacher.',
      );
    }

    String value(String field) => invitation[field]?.toString().trim() ?? '';
    final name = value('name');
    final now = FieldValue.serverTimestamp();
    final profileData = <String, dynamic>{
      'uid': uid,
      'email': email,
      'role': 'student',
      'firstName': value('firstName'),
      'middleName': value('middleName'),
      'lastName': value('lastName'),
      'extension': value('extension'),
      'name': name,
      'displayName': name,
      'invitationStatus': 'sent',
      'invitedAt': now,
      'invitedBy': value('teacherId'),
      'invitedClassId': classId,
      'accountRepairId': repairId,
      'currentClassId': classId,
      'currentClassName': classData['name']?.toString() ?? 'Unnamed Class',
      'currentTeacherName':
          classData['teacherName']?.toString() ?? 'Unknown Teacher',
      'createdAt': now,
      'updatedAt': now,
    };
    final profileBatch = firestore.batch();
    profileBatch.set(firestore.collection('users').doc(uid), profileData);
    profileBatch.set(firestore.collection('students').doc(uid), profileData);
    await profileBatch.commit();
    await repair.update({
      'status': 'claimed',
      'claimedUid': uid,
      'claimedAt': now,
      'updatedAt': now,
    });
    await _completeRecoveredEnrollment(
      firestore: firestore,
      uid: uid,
      profile: profileData,
      classroom: classroom,
      classId: classId,
      classData: classData,
    );
    return true;
  }

  static Future<void> _markRepairClaimed({
    required FirebaseFirestore firestore,
    required String repairId,
    required String uid,
  }) async {
    final repair = firestore.collection('student_account_repairs').doc(repairId);
    final snapshot = await repair.get();
    if (snapshot.data()?['status'] != 'pending') return;
    await repair.update({
      'status': 'claimed',
      'claimedUid': uid,
      'claimedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _completeRecoveredEnrollment({
    required FirebaseFirestore firestore,
    required String uid,
    required Map<String, dynamic> profile,
    required DocumentReference<Map<String, dynamic>> classroom,
    required String classId,
    required Map<String, dynamic> classData,
  }) async {
    final now = FieldValue.serverTimestamp();
    final batch = firestore.batch();
    batch.set(
      firestore.collection('users').doc(uid).collection('classes').doc(classId),
      membershipData(classId, classData),
    );
    batch.set(classroom.collection('students').doc(uid), {
      'uid': uid,
      'name': profile['name']?.toString() ?? 'Student',
      'email': profile['email']?.toString() ?? '',
      'role': 'student',
      'joinedAt': now,
      'status': 'active',
    });
    batch.update(classroom, {
      'enrolledStudentIds': FieldValue.arrayUnion([uid]),
      'updatedAt': now,
    });
    await batch.commit();
  }
}
